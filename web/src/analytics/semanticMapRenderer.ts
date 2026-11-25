// The semantic map's renderer (PLAN's S28b), WebGL2 alone, as the app's Metal renderer draws (`SemanticMapRenderer`):
// every point in one draw call, a round sprite of two of the canvas's own pixels with a soft edge, in its slot of the
// lens's palette, blended over the app's dark ground; drawn when the view changes, never on a clock. The vertex buffer
// is the server's answer as it came, six bytes a point, so the 314,616 points cost 1.9 MB once, on the GPU, and the
// shader reads each point's place from it as the app's reads its own. Since S28c each point's slot under the lens is
// the server's, the kit's colouring, one byte a point in a buffer of its own, and so is a scope's mask, which the
// shader ghosts as the app's does: a point outside the scope grey, at a fixed alpha, and one inside raised to a floor.
//
// deck.gl was measured first, against the app's policy (no unsafe-eval, no style sheet of its own, no worker from a blob):
// 9.4.1 draws under it, but its scatter of the same points took a median 5.4 ms a frame where this takes 1.2 on the
// owner's Mac's GPU, and 4.9 s where this takes 36 ms under Chromium's software renderer, which CI's browser suite runs
// on, with 17 MB more of the page's heap and 594 KB more of script (docs/DEVLOG.md, Session 28b).
import { type MapCamera, background, cameraScale, paletteSize, pointSize, type Rgba } from './semanticMapRules';

const vertexShader = `#version 300 es
layout(location = 0) in vec2 position;
layout(location = 1) in uint slot;
layout(location = 2) in uint flags;
uniform vec2 centre;
uniform vec2 scale;
uniform float pointSize;
uniform float scopeActive;
uniform vec4 palette[${paletteSize}];
out vec4 colour;
void main() {
  gl_Position = vec4((position - centre) / scale, 0.0, 1.0);
  gl_PointSize = pointSize;
  colour = palette[min(slot, ${paletteSize - 1}u)];
  if ((flags & 1u) != 0u) {
    float grey = dot(colour.rgb, vec3(0.2126, 0.7152, 0.0722)) * 0.55;
    colour = vec4(grey, grey, grey, 0.16);
  } else if (scopeActive > 0.5) {
    colour.a = max(colour.a, 0.45);
  }
}`;

// Round rather than square, with the app's soft edge: its smoothstep(0.5, 0.35, d), which GLSL leaves undefined with its
// edges reversed, written as the same curve with them in order.
const fragmentShader = `#version 300 es
precision mediump float;
in vec4 colour;
out vec4 fragment;
void main() {
  float d = length(gl_PointCoord - vec2(0.5));
  if (d > 0.5) discard;
  float edge = 1.0 - smoothstep(0.35, 0.5, d);
  fragment = vec4(colour.rgb, colour.a * edge);
}`;

/** The context's settings: an opaque drawing buffer the ground fills, with nothing the map does not use. */
const contextAttributes: WebGLContextAttributes = {
  alpha: false,
  antialias: false,
  depth: false,
  stencil: false,
  preserveDrawingBuffer: false,
  premultipliedAlpha: true,
};

let probed: boolean | undefined;

/** Whether this browser gives WebGL2, asked once of a canvas of its own, which is let go at once. */
export function supportsWebGL2(): boolean {
  if (probed === undefined) {
    try {
      const context = document.createElement('canvas').getContext('webgl2', contextAttributes);
      probed = context !== null;
      context?.getExtension('WEBGL_lose_context')?.loseContext();
    } catch {
      probed = false;
    }
  }
  return probed;
}

function compile(gl: WebGL2RenderingContext, type: number, source: string): WebGLShader {
  const shader = gl.createShader(type);
  if (!shader) throw new Error('The map’s shader could not be made.');
  gl.shaderSource(shader, source);
  gl.compileShader(shader);
  if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS) && !gl.isContextLost()) {
    const log = gl.getShaderInfoLog(shader) ?? '';
    gl.deleteShader(shader);
    throw new Error(`The map’s shader did not compile: ${log}`);
  }
  return shader;
}

/** One canvas's renderer: its program, the points', the slots' and the scope's buffers, and the uniforms the camera sets. */
export class SemanticMapRenderer {
  private readonly gl: WebGL2RenderingContext;
  private readonly program: WebGLProgram;
  private readonly buffer: WebGLBuffer;
  private readonly slotBuffer: WebGLBuffer;
  private readonly flagBuffer: WebGLBuffer;
  private readonly vertexArray: WebGLVertexArrayObject;
  private readonly centre: WebGLUniformLocation | null;
  private readonly scale: WebGLUniformLocation | null;
  private readonly pointSizeAt: WebGLUniformLocation | null;
  private readonly scopeActiveAt: WebGLUniformLocation | null;
  private readonly paletteAt: WebGLUniformLocation | null;
  private count = 0;
  private slotCount = 0;

  /** Throws when the canvas gives no WebGL2 or the program cannot be made. */
  constructor(canvas: HTMLCanvasElement, palette: readonly Rgba[]) {
    const gl = canvas.getContext('webgl2', contextAttributes);
    if (!gl) throw new Error('This browser gives no WebGL2.');
    this.gl = gl;
    const program = gl.createProgram();
    const buffer = gl.createBuffer();
    const slotBuffer = gl.createBuffer();
    const flagBuffer = gl.createBuffer();
    const vertexArray = gl.createVertexArray();
    const letGo = () => {
      gl.deleteProgram(program);
      gl.deleteBuffer(buffer);
      gl.deleteBuffer(slotBuffer);
      gl.deleteBuffer(flagBuffer);
      gl.deleteVertexArray(vertexArray);
    };
    if (!program || !buffer || !slotBuffer || !flagBuffer || !vertexArray) {
      letGo();
      throw new Error('The map’s program could not be made.');
    }
    let shaders: WebGLShader[] = [];
    try {
      shaders = [compile(gl, gl.VERTEX_SHADER, vertexShader)];
      shaders.push(compile(gl, gl.FRAGMENT_SHADER, fragmentShader));
    } catch (error) {
      for (const shader of shaders) gl.deleteShader(shader);
      letGo();
      throw error;
    }
    for (const shader of shaders) gl.attachShader(program, shader);
    gl.linkProgram(program);
    // Linked, the program keeps what it needs: the shaders go now.
    for (const shader of shaders) {
      gl.detachShader(program, shader);
      gl.deleteShader(shader);
    }
    if (!gl.getProgramParameter(program, gl.LINK_STATUS) && !gl.isContextLost()) {
      const log = gl.getProgramInfoLog(program) ?? '';
      letGo();
      throw new Error(`The map’s program did not link: ${log}`);
    }
    this.program = program;
    this.buffer = buffer;
    this.slotBuffer = slotBuffer;
    this.flagBuffer = flagBuffer;
    this.vertexArray = vertexArray;
    gl.useProgram(program);
    gl.bindVertexArray(vertexArray);
    gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
    // Six bytes a point: x and y as int16, read as floats; the region beside them is the server's, which the slots carry.
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 2, gl.SHORT, false, 6, 0);
    // A byte a point: the lens's slot.
    gl.bindBuffer(gl.ARRAY_BUFFER, slotBuffer);
    gl.enableVertexAttribArray(1);
    gl.vertexAttribIPointer(1, 1, gl.UNSIGNED_BYTE, 1, 0);
    // A byte a point under a scope, bit 0 out of it; with none, every point in (the attribute's constant 0).
    gl.bindBuffer(gl.ARRAY_BUFFER, flagBuffer);
    gl.vertexAttribIPointer(2, 1, gl.UNSIGNED_BYTE, 1, 0);
    gl.disableVertexAttribArray(2);
    gl.vertexAttribI4ui(2, 0, 0, 0, 0);
    this.paletteAt = gl.getUniformLocation(program, 'palette');
    gl.uniform4fv(this.paletteAt, new Float32Array(palette.flat()));
    this.centre = gl.getUniformLocation(program, 'centre');
    this.scale = gl.getUniformLocation(program, 'scale');
    this.pointSizeAt = gl.getUniformLocation(program, 'pointSize');
    this.scopeActiveAt = gl.getUniformLocation(program, 'scopeActive');
    gl.uniform1f(this.scopeActiveAt, 0);
    // The app's blending: colour by the source's alpha, coverage by one.
    gl.enable(gl.BLEND);
    gl.blendEquation(gl.FUNC_ADD);
    gl.blendFuncSeparate(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA, gl.ONE, gl.ONE_MINUS_SRC_ALPHA);
    gl.clearColor(background[0], background[1], background[2], background[3]);
  }

  /** The points, as the server's answer gives them: six bytes each. */
  setPoints(points: ArrayBuffer): void {
    const gl = this.gl;
    gl.bindBuffer(gl.ARRAY_BUFFER, this.buffer);
    gl.bufferData(gl.ARRAY_BUFFER, points, gl.STATIC_DRAW);
    this.count = Math.floor(points.byteLength / 6);
  }

  /** A lens: its slot for every point, as the server gives them, and its palette. */
  setLens(slots: Uint8Array, palette: readonly Rgba[]): void {
    const gl = this.gl;
    gl.useProgram(this.program);
    gl.bindBuffer(gl.ARRAY_BUFFER, this.slotBuffer);
    gl.bufferData(gl.ARRAY_BUFFER, slots, gl.STATIC_DRAW);
    this.slotCount = slots.length;
    gl.uniform4fv(this.paletteAt, new Float32Array(palette.flat()));
  }

  /** A scope's mask, a byte a point, or none for the whole series, which ghosts nothing (`setScopeFlags`). */
  setScope(flags: Uint8Array | undefined): void {
    const gl = this.gl;
    gl.useProgram(this.program);
    gl.bindVertexArray(this.vertexArray);
    // A mask of another length is stale, and draws the map unscoped rather than ghosting the wrong points.
    const scoped = flags !== undefined && flags.length === this.count;
    if (scoped) {
      gl.bindBuffer(gl.ARRAY_BUFFER, this.flagBuffer);
      gl.bufferData(gl.ARRAY_BUFFER, flags, gl.STATIC_DRAW);
      gl.enableVertexAttribArray(2);
    } else {
      gl.disableVertexAttribArray(2);
      gl.vertexAttribI4ui(2, 0, 0, 0, 0);
    }
    gl.uniform1f(this.scopeActiveAt, scoped ? 1 : 0);
  }

  /** How many points the buffer holds. */
  get pointCount(): number {
    return this.count;
  }

  /** Draws every point through `camera` into the canvas's drawing buffer, whose size the caller has set. */
  draw(camera: MapCamera): void {
    const gl = this.gl;
    if (gl.isContextLost()) return;
    const width = gl.drawingBufferWidth;
    const height = gl.drawingBufferHeight;
    gl.viewport(0, 0, width, height);
    gl.useProgram(this.program);
    gl.bindVertexArray(this.vertexArray);
    const [scaleX, scaleY] = cameraScale(camera, height > 0 ? width / height : 1);
    gl.uniform2f(this.centre, camera.centre[0], camera.centre[1]);
    gl.uniform2f(this.scale, scaleX, scaleY);
    gl.uniform1f(this.pointSizeAt, pointSize);
    gl.clear(gl.COLOR_BUFFER_BIT);
    // Points are drawn once each has its slot: never with a lens of another count.
    if (this.count > 0 && this.slotCount === this.count) gl.drawArrays(gl.POINTS, 0, this.count);
  }

  /** The largest drawing buffer the context allows a side of. */
  get maximumSide(): number {
    const dimensions = this.gl.getParameter(this.gl.MAX_VIEWPORT_DIMS) as Int32Array | null;
    return dimensions ? Math.min(dimensions[0] ?? 4096, dimensions[1] ?? 4096) : 4096;
  }

  /** Gives the context back to the browser at once, after `dispose()`, for a canvas drawn once and let go: a figure's plate. */
  release(): void {
    this.gl.getExtension('WEBGL_lose_context')?.loseContext();
  }

  /** Lets go of what the renderer made on the GPU. */
  dispose(): void {
    const gl = this.gl;
    if (gl.isContextLost()) return;
    gl.deleteBuffer(this.buffer);
    gl.deleteBuffer(this.slotBuffer);
    gl.deleteBuffer(this.flagBuffer);
    gl.deleteVertexArray(this.vertexArray);
    gl.deleteProgram(this.program);
  }
}
