// Answers of the server's Source Explorer routes over the kit's fixture index, taken from a run of the
// server (PLAN's S22d) and trimmed: each list of neighbours to three rows, a record's volumes to seven.
import type { ArchivalCollection, ArchivalNeighbours, SourceExplorer } from '../api/sources';

export const sources = {
  "centralFiles": {
    "classificationMarking": "Unclassified; Niact",
    "collection": {
      "id": "txt:department of state|central file",
      "name": "Central Files",
      "volumeCount": 158
    },
    "dateline": "Washington, January 21, 1961, 6:34 p.m.",
    "documentId": "d4",
    "documentTitle": "4. Telegram From the Department of State to the Embassy in the Soviet Union",
    "hasSourceNote": true,
    "neighbours": {
      "basis": "Same decimal file — 711.11-KE, 1960–January 1963",
      "documents": [
        {
          "dateline": "Washington, April 12, 1961, 1:24 p.m.",
          "documentId": "d8",
          "number": "8",
          "title": "Telegram From the Department of State to the Embassy in the Soviet Union",
          "volumeId": "frus1961-63v06"
        },
        {
          "dateline": "Washington, July 4, 1961.",
          "documentId": "d19",
          "number": "19",
          "title": "Telegram From President Kennedy to Chairmen Khrushchev and Brezhnev",
          "volumeId": "frus1961-63v06"
        }
      ],
      "matchKey": "711.11-KE",
      "totalCount": 2
    },
    "parsed": {
      "fields": {
        "fileIdentifier": "711.11-KE/1-2161",
        "recordGroup": "RG-59"
      },
      "kind": "centralFiles"
    },
    "provenance": [
      {
        "fileIdentifier": "711.11-KE/1-2161",
        "kind": "centralFiles",
        "recordGroup": "RG 59"
      },
      {
        "kind": "filingPeriod",
        "manual": {
          "url": "https://www.archives.gov/files/research/foreign-policy/state-dept/finding-aids/manual-1960-63.pdf"
        },
        "period": {
          "label": "1960–January 1963",
          "url": "https://www.archives.gov/research/foreign-policy/state-dept/rg-59-central-files/1910-1963"
        }
      }
    ],
    "rawSourceNote": "Source: Department of State, Central Files, 711.11-KE/1-2161. Unclassified; Niact. Drafted by McSweeney and Veliotes (SOV) and cleared by Goodpaster, Kretzmann, and Rusk. Another copy of this message is in the Kennedy Library, National Security Files, Countries Series, USSR, Khrushchev Correspondence. Also printed in Public Papers of the Presidents of the United States: John F. Kennedy, 1961, p. 3, and American Foreign Policy: Current Documents, 1961, p. 560.",
    "volumeId": "frus1961-63v06",
    "year": 1961
  },
  "cfpf": {
    "classificationMarking": "Secret",
    "dateline": "Washington, March 29, 1973, 2230Z.",
    "documentId": "d8",
    "documentTitle": "8. Telegram 51869 From the Department of State to the Mission to the United Nations",
    "hasSourceNote": true,
    "neighbours": {
      "documents": [],
      "emptyState": "unmatched",
      "totalCount": 0
    },
    "parsed": {
      "fields": {},
      "kind": "cfpfFile"
    },
    "provenance": [
      {
        "kind": "cfpf",
        "links": [
          {
            "url": "https://www.archives.gov/files/research/foreign-policy/state-dept/rg-59-central-files/cfpf-faqs.pdf"
          },
          {
            "url": "https://aad.archives.gov/aad/series-list.jsp?cat=WR43"
          }
        ]
      }
    ],
    "rawSourceNote": "Source: National Archives, RG 59, Central Foreign Policy Files. Secret. Drafted by Warren Clark, Jr. in AF/N; cleared by Ernest Thomas Greene in IO/UNP; and approved by Clark. Sent for action to Tripoli, and repeated to USCINCEUR and CINCUSAFE.",
    "volumeId": "frus1969-76ve09p1",
    "year": 1973
  },
  "cia": {
    "classificationMarking": "Secret, [text not declassified]",
    "collection": {
      "id": "txt:central intelligence agency|office of the director of central intelligence",
      "name": "Office of the Director of Central Intelligence",
      "volumeCount": 34
    },
    "dateline": "Washington, April 19, 1973.",
    "documentId": "d15",
    "documentTitle": "15. Memorandum From Director of Central Intelligence Schlesinger to the President’s Assistant for National Security Affairs (Kissinger)",
    "hasSourceNote": true,
    "neighbours": {
      "documents": [
        {
          "dateline": "Washington, October 3, 1975.",
          "documentId": "d93",
          "number": "93",
          "title": "Memorandum From Director of Central Intelligence Colby to the President’s Assistant for National Security Affairs (Kissinger)",
          "volumeId": "frus1969-76ve09p1"
        }
      ],
      "matchKey": "CIA Job 80M01066A",
      "totalCount": 1
    },
    "parsed": {
      "fields": {
        "box": "13",
        "description": "Central Intelligence Agency, Office of the Director of Central Intelligence, Job 80M01066A, OPI 10, Box 13, Folder 8. Secret, [text not declassified].",
        "jobNumber": "80M01066A"
      },
      "kind": "ciaCollection"
    },
    "provenance": [
      {
        "box": "13",
        "description": "Central Intelligence Agency, Office of the Director of Central Intelligence, Job 80M01066A, OPI 10, Box 13, Folder 8. Secret, [text not declassified].",
        "jobNumber": "80M01066A",
        "kind": "cia",
        "link": {
          "url": "https://www.cia.gov/readingroom/search/site/80M01066A"
        }
      }
    ],
    "rawSourceNote": "Source: Central Intelligence Agency, Office of the Director of Central Intelligence, Job 80M01066A, OPI 10, Box 13, Folder 8. Secret, [text not declassified].",
    "volumeId": "frus1969-76ve09p1",
    "year": 1973
  },
  "library": {
    "classificationMarking": "Secret; Niact; Verbatim Text",
    "collection": {
      "id": "txt:kennedy library|national security file",
      "name": "National Security Files",
      "volumeCount": 30
    },
    "dateline": "Washington, May 16, 1961, 1:33 p.m.",
    "documentId": "d15",
    "documentTitle": "15. Telegram From the Department of State to Secretary of State Rusk at Geneva",
    "hasSourceNote": true,
    "neighbours": {
      "basis": "Same collection — Kennedy Library",
      "documents": [
        {
          "dateline": "Hyannis Port, October 16, 1961.",
          "documentId": "d22",
          "number": "22",
          "title": "Letter From President Kennedy to Chairman Khrushchev",
          "volumeId": "frus1961-63v06"
        },
        {
          "dateline": "Moscow, undated",
          "documentId": "d30",
          "number": "30",
          "title": "Message From Chairman Khrushchev to President Kennedy",
          "volumeId": "frus1961-63v06"
        },
        {
          "dateline": "Washington, February 6, 1962, 6:42 p.m.",
          "documentId": "d31",
          "number": "31",
          "title": "Telegram From the Department of State to the Embassy in the Soviet Union",
          "volumeId": "frus1961-63v06"
        }
      ],
      "matchKey": "Kennedy Library: National Security Files",
      "totalCount": 22
    },
    "parsed": {
      "fields": {
        "collection": "National Security Files",
        "fileIdentifier": "Files",
        "library": "Kennedy Library"
      },
      "kind": "presidentialLibrary"
    },
    "provenance": [
      {
        "fileIdentifier": "Files",
        "kind": "presidentialLibrary",
        "library": "Kennedy Library",
        "libraryCollection": "National Security Files"
      },
      {
        "kind": "curatedLibrary",
        "link": {
          "url": "https://www.jfklibrary.org/asset-viewer/archives/jfknsf"
        },
        "rationale": "The library publishes ONE finding aid for the whole subcollection — administrative overview, series list and container list on a single page — so there is no more specific published destination for a series citation. The page's own series list is the next step.",
        "title": "Papers of John F. Kennedy. Presidential Papers. National Security Files"
      },
      {
        "kind": "offlineLibrary",
        "libraryOutcome": {
          "candidates": [],
          "caveat": "The collection is identified, but the citation does not name one of its 17 series unambiguously. Open the collection record to find the series cited.",
          "collection": {
            "catalogURL": "https://catalog.archives.gov/id/1164",
            "label": "Collection",
            "title": "Papers of John F. Kennedy: Presidential Papers: National Security Files"
          },
          "provenanceNote": "Matched against the National Archives' own description of this library, from the bundled catalog — no API key or network required.",
          "sectionTitle": "NARA Catalog"
        }
      }
    ],
    "rawSourceNote": "Source: Kennedy Library, National Security Files, Countries Series, USSR, Khrushchev Correspondence. Secret; Niact; Verbatim Text. Repeated to Moscow. Another copy is in Department of State, Central Files, 761.13/5-1661. A copy of the Russian-language text is ibid., Presidential Correspondence: Lot 66 D 204.",
    "unprinted": {
      "footer": "Archival units this document’s footnotes cite for material FRUS did not print. Each is a separate claim from the source note above, which records where this document itself was drawn from, even when the two name the same unit.",
      "rows": [
        {
          "clause": "Department of State, Central Files, 711.11-KE/5-1661",
          "id": "2|0||Department of State||711.11-KE",
          "inherited": false,
          "source": "stateDeptSchedule",
          "spokenTitle": "Footnote 3, 711.11-KE",
          "title": "fn 3 · 711.11-KE"
        },
        {
          "clause": "ibid.",
          "id": "2|1||Department of State||711.11-KE",
          "inherited": true,
          "source": "stateDeptSchedule",
          "spokenTitle": "Footnote 3, 711.11-KE",
          "title": "fn 3 · 711.11-KE"
        }
      ]
    },
    "volumeId": "frus1961-63v06",
    "year": 1961
  },
  "lot": {
    "classificationMarking": "No classification marking",
    "collection": {
      "id": "lot:66D204",
      "name": "Presidential Correspondence: Lot 66 D 204",
      "volumeCount": 83
    },
    "dateline": "Moscow, January 20, 1961.",
    "documentId": "d3",
    "documentTitle": "3. Message From Chairmen Khrushchev and Brezhnev to President Kennedy",
    "hasSourceNote": true,
    "neighbours": {
      "basis": "Same lot file — 66 D 204",
      "documents": [
        {
          "dateline": "Moscow, February 15, 1961.",
          "documentId": "d6",
          "number": "6",
          "title": "Message From Chairman Khrushchev to President Kennedy",
          "volumeId": "frus1961-63v06"
        },
        {
          "dateline": "Washington, February 22, 1961.",
          "documentId": "d7",
          "number": "7",
          "title": "Letter From President Kennedy to Chairman Khrushchev",
          "volumeId": "frus1961-63v06"
        },
        {
          "dateline": "Moscow, April 18, 1961, 2 p.m.",
          "documentId": "d9",
          "number": "9",
          "title": "Telegram From the Embassy in the Soviet Union to the Department of State",
          "volumeId": "frus1961-63v06"
        }
      ],
      "matchKey": "Lot 66 D 204",
      "totalCount": 58
    },
    "parsed": {
      "fields": {
        "fileIdentifier": "Files",
        "lotNumber": "66 D 204",
        "recordGroup": "RG-59"
      },
      "kind": "lotFile"
    },
    "provenance": [
      {
        "fileIdentifier": "Files",
        "kind": "lotFile",
        "lotNumber": "66 D 204",
        "postRecords": false,
        "recordGroup": "RG 59",
        "recordGroupSource": "frusText"
      },
      {
        "kind": "bundledLot",
        "lot": {
          "accessRestrictions": [],
          "accessStatus": "Restricted - Possibly",
          "catalogURL": "https://catalog.archives.gov/id/2538452",
          "creator": "Department of State. Office of the Secretary. Executive Secretariat.",
          "entryNumbers": [
            "A1 1590"
          ],
          "extent": "9 linear feet, 8 linear inches",
          "heldAt": "National Archives at College Park - Textual Reference",
          "title": "Presidential and Secretary of State Correspondence with Foreign Heads of State",
          "years": "1953–1964"
        }
      },
      {
        "catalogQuery": {
          "manualSearchURL": "https://catalog.archives.gov/search-within/388?q=Lot%2066%20D%20204",
          "route": "lotVariants"
        },
        "kind": "naraCatalog"
      }
    ],
    "rawSourceNote": "Source: Department of State, Presidential Correspondence: Lot 66 D 204. No classification marking. The source text is a Department of State translation of a commercial telegram from Moscow. Another copy of this message is in the Kennedy Library, National Security Files, Countries Series, USSR, Khrushchev Correspondence. This message is also printed in Public Papers of the Presidents of the United States: John F. Kennedy, 1961, p. 3, and American Foreign Policy: Current Documents, 1961, p. 559.",
    "volumeId": "frus1961-63v06",
    "year": 1961
  },
  "named": {
    "classificationMarking": "Secret; Priority; Exdis",
    "collection": {
      "id": "txt:|osd file",
      "name": "OSD Files",
      "volumeCount": 12
    },
    "dateline": "Washington, April 5, 1973, 1529Z.",
    "documentId": "d10",
    "documentTitle": "10. Telegram 62911 From the Department of State to the Embassy in Libya",
    "hasSourceNote": true,
    "neighbours": {
      "documents": [],
      "emptyState": "unmatched",
      "totalCount": 0
    },
    "parsed": {
      "fields": {
        "fileIdentifier": "FRC 330–780002, Box 6, Libya 452",
        "seriesName": "OSD Files"
      },
      "kind": "namedFileSeries"
    },
    "provenance": [
      {
        "explainer": "A named file series cited without a lot number. The repository is not stated in the citation.",
        "fileIdentifier": "FRC 330–780002, Box 6, Libya 452",
        "kind": "namedFileSeries",
        "link": {
          "label": "Department of State records at the National Archives",
          "url": "https://www.archives.gov/research/foreign-policy/state-dept/agency-records"
        },
        "seriesName": "OSD Files"
      }
    ],
    "rawSourceNote": "Source: Washington National Records Center, OSD Files: FRC 330–780002, Box 6, Libya 452. Secret; Priority; Exdis. Drafted by James J. Blake in AF/N on April 3; cleared by Miller in S/S, Assistant Secretary for African Affairs David D. Newsom, in substance by Assistant Secretary for Near Eastern and South Asian Affairs Joseph Sisco, and in substance by the Director of the Bureau of Intelligence and Research Ray S. Cline; and approved by the Under Secretary for Political Affairs William J. Porter. A notation on the document reads: “Deputy Secretary has seen.” In telegram 449 from Tripoli, April 10, the Embassy informed the Department that the note was delivered that morning. (Ibid.)",
    "volumeId": "frus1969-76ve09p1",
    "year": 1973
  },
  "noNote": {
    "dateline": "Bluefields, Nicaragua, January 25, 1894.",
    "documentId": "d1",
    "documentTitle": "No. 1. Mr. Seat to Mr. Gresham.",
    "hasSourceNote": false,
    "neighbours": {
      "documents": [],
      "emptyState": "unmatched",
      "totalCount": 0
    },
    "noSourceNote": {
      "predictedSeries": "diplomatic",
      "state": "noMatch"
    },
    "parsed": {
      "fields": {
        "rawText": ""
      },
      "kind": "unrecognized"
    },
    "provenance": [],
    "rawSourceNote": "",
    "volumeId": "frus1894Nicaragua",
    "year": 1894
  },
  "outside": {
    "classificationMarking": "Secret; Sensitive; Exclusively Eyes Only",
    "collection": {
      "id": "txt:library of congress|manuscript division",
      "name": "Manuscript Division",
      "volumeCount": 87
    },
    "dateline": "Washington, April 30, 1974.",
    "documentId": "d1",
    "documentTitle": "1. Memorandum From the Deputy Assistant to the President for National Security Affairs (Scowcroft) to President Nixon",
    "hasSourceNote": true,
    "neighbours": {
      "basis": "Same collection — Library of Congress",
      "documents": [
        {
          "dateline": "Damascus, May 21, 1974, 1448Z.",
          "documentId": "d2",
          "number": "2",
          "title": "Telegram 828/Secto 574 From the Interests Section in Syria to the Interests Section in Algeria",
          "volumeId": "frus1969-76ve09p1"
        },
        {
          "dateline": "Washington, June 8, 1974, 2253Z.",
          "documentId": "d3",
          "number": "3",
          "title": "Telegram 121825 From the Department of State to the Interests Section in Algeria",
          "volumeId": "frus1969-76ve09p1"
        },
        {
          "dateline": "Algiers, June 29, 1974, 1050Z.",
          "documentId": "d4",
          "number": "4",
          "title": "Telegram 1410 From the Interests Section in Algeria to the Department of State",
          "volumeId": "frus1969-76ve09p1"
        }
      ],
      "matchKey": "Library of Congress: Manuscript Division",
      "totalCount": 26
    },
    "parsed": {
      "fields": {
        "collection": "Manuscript Division",
        "fileIdentifier": "Box CL 101",
        "library": "Library of Congress"
      },
      "kind": "presidentialLibrary"
    },
    "provenance": [
      {
        "fileIdentifier": "Box CL 101",
        "kind": "presidentialLibrary",
        "library": "Library of Congress",
        "libraryCollection": "Manuscript Division"
      },
      {
        "kind": "curatedLibrary",
        "link": {
          "url": "https://hdl.loc.gov/loc.mss/eadmss.ms016034"
        },
        "rationale": "Part I covers Kissinger's service as National Security Adviser 1969–1975 and Secretary of State 1973–1977, in 26 series spanning 1957–1982 — the FRUS era. Part II is at Yale and is distinguishable by its citations; the corpus contains none. Library of Congress collections carry no NARA identifier.",
        "title": "Henry A. Kissinger Papers, Part I"
      },
      {
        "guidance": {
          "citedAsLabel": "Cited here as",
          "holdings": "The Manuscript Reading Room in the Madison Building, Washington, D.C., holds the personal papers this citation names. Finding aids for individual collections are published separately.",
          "link": {
            "label": "Open Library of Congress, Manuscript Division",
            "url": "https://www.loc.gov/research-centers/manuscript/about-this-research-center/"
          },
          "name": "Library of Congress, Manuscript Division"
        },
        "kind": "outsideNARA",
        "library": "Library of Congress"
      }
    ],
    "rawSourceNote": "Source: Library of Congress, Manuscript Division, Kissinger Papers, Box CL 101, Geopolitical File, Algeria, April–May 1974. Secret; Sensitive; Exclusively Eyes Only. Kissinger met with Boumediene in Algiers en route to the Middle East.",
    "volumeId": "frus1969-76ve09p1",
    "year": 1974
  },
  "pre1906": {
    "countrySeries": {
      "homes": [
        {
          "category": "Consular Despatches",
          "chiefOfMission": false,
          "confidence": "Likely",
          "confidenceLevel": "high",
          "rationale": "Dateline is a U.S. consulate abroad — a consular despatch to the Department.",
          "rolls": [
            {
              "catalogURL": "https://catalog.archives.gov/id/212052044",
              "title": "Despatches: January 8, 1891 - February 24, 1894"
            }
          ]
        }
      ]
    },
    "dateline": "Consulate of the United States, San Juan del Norte, February 13, 1894. (Received February 27.)",
    "documentId": "d5",
    "documentTitle": "No. 5. Mr. Braida to Mr. Uhl.",
    "hasSourceNote": false,
    "neighbours": {
      "documents": [],
      "emptyState": "unmatched",
      "totalCount": 0
    },
    "parsed": {
      "fields": {
        "rawText": ""
      },
      "kind": "unrecognized"
    },
    "provenance": [],
    "rawSourceNote": "",
    "volumeId": "frus1894Nicaragua",
    "year": 1894
  },
  "subjectNumeric": {
    "classificationMarking": "Secret; Exdis",
    "collection": {
      "id": "txt:department of state|central files 1970-73",
      "name": "Central Files 1970–73",
      "volumeCount": 52
    },
    "dateline": "Washington, May 10, 1973.",
    "documentId": "d17",
    "documentTitle": "17. Memorandum From the Under Secretary of State for Political Affairs (Porter) to Secretary of State Rogers",
    "hasSourceNote": true,
    "neighbours": {
      "basis": "Same Subject-Numeric file — POL LIBYA-US",
      "documents": [
        {
          "dateline": "Washington, November 23, 1973.",
          "documentId": "d29",
          "number": "29",
          "title": "Briefing Memorandum From the Assistant Secretary of State for African Affairs (Newsom) to Secretary of State Kissinger",
          "volumeId": "frus1969-76ve09p1"
        }
      ],
      "matchKey": "POL LIBYA-US",
      "totalCount": 1
    },
    "parsed": {
      "fields": {
        "recordGroup": "59",
        "series": "Central Files 1970–73"
      },
      "kind": "naraCollection"
    },
    "provenance": [
      {
        "block": "1970–73",
        "designation": "POL Libya-U.S",
        "handbooks": [
          {
            "label": "Classification Handbook 1965–73 (PDF)",
            "url": "https://www.archives.gov/files/research/foreign-policy/state-dept/finding-aids/dos-records-classification-handbook-1965-1973.pdf"
          }
        ],
        "kind": "subjectNumeric",
        "period": {
          "url": "https://www.archives.gov/research/foreign-policy/state-dept/rg-59-central-files/1963-1973"
        }
      }
    ],
    "rawSourceNote": "Source: National Archives, RG 59, Central Files 1970–73, POL Libya-U.S. Secret; Exdis. Drafted by Director of North African Affairs James J. Blake on May 10. Rogers approved the recommendations May 11. The recommendations were sent from Eliot to Kissinger under a May 17 covering memorandum.",
    "volumeId": "frus1969-76ve09p1",
    "year": 1973
  }
} as unknown as Record<string, SourceExplorer>;

export const neighbours = {
  "anchorVolumeId": "frus1961-63v06",
  "basis": "Lot 66 D 204",
  "documents": [
    {
      "dateline": "Moscow, February 15, 1961.",
      "documentId": "d6",
      "title": "6. Message From Chairman Khrushchev to President Kennedy",
      "volumeId": "frus1961-63v06"
    },
    {
      "dateline": "Washington, February 22, 1961.",
      "documentId": "d7",
      "title": "7. Letter From President Kennedy to Chairman Khrushchev",
      "volumeId": "frus1961-63v06"
    },
    {
      "dateline": "Moscow, April 18, 1961, 2 p.m.",
      "documentId": "d9",
      "title": "9. Telegram From the Embassy in the Soviet Union to the Department of State",
      "volumeId": "frus1961-63v06"
    }
  ],
  "scope": "all",
  "scopes": [
    "volume",
    "subseries",
    "all"
  ],
  "totalCount": 58
} as unknown as ArchivalNeighbours;

export const collection = {
  "aliases": [
    "66 D 204",
    "Presidential Correspondence",
    "Presidential Correspondence files",
    "Presidential Correspondence, Lot 66 D 204",
    "Presidential Files",
    "Presidential Memoranda of Conversation",
    "Presidential Memoranda of Conversation: Lot 66 D 204",
    "Seoul Embassy Files"
  ],
  "children": [
    {
      "name": "Presidential exchanges of correspondence with heads of government for 1953-1964",
      "volumeCount": 2
    }
  ],
  "documentCount": 59,
  "id": "lot:66D204",
  "lotFileNorm": "66D204",
  "name": "Presidential Correspondence: Lot 66 D 204",
  "recordGroup": "59",
  "repository": "Department of State",
  "volumeCount": 1,
  "volumes": [
    {
      "title": "Foreign Relations of the United States, 1952–1954, General: Economic and Political Matters, Volume I, Part 1",
      "volumeId": "frus1952-54v01p1"
    },
    {
      "title": "Foreign Relations of the United States, 1952–1954, General: Economic and Political Matters, Volume I, Part 2",
      "volumeId": "frus1952-54v01p2"
    },
    {
      "title": "Foreign Relations of the United States, 1952–1954, National Security Affairs, Volume II, Part 2",
      "volumeId": "frus1952-54v02p2"
    },
    {
      "title": "Foreign Relations of the United States, 1952–1954, Western European Security, Volume V, Part 1",
      "volumeId": "frus1952-54v05p1"
    },
    {
      "title": "Foreign Relations of the United States, 1952–1954, Western European Security, Volume V, Part 2",
      "volumeId": "frus1952-54v05p2"
    },
    {
      "title": "Foreign Relations of the United States, 1952–1954, Western Europe and Canada, Volume VI, Part 1",
      "volumeId": "frus1952-54v06p1"
    },
    {
      "title": "Foreign Relations of the United States, 1952–1954, Western Europe and Canada, Volume VI, Part 2",
      "volumeId": "frus1952-54v06p2"
    }
  ]
} as unknown as ArchivalCollection;
