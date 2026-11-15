// Answers of the server's Source Explorer routes over the kit's fixture index, taken from a run of the
// server (PLAN's S22d; the record and the outline again in its follow-up) and trimmed: each list of
// neighbours to three rows, a record's volumes, related collections and pointed-at volumes to seven each,
// lot 66 D 204's record and lot 64 D 563's, which NARA divided, and frus1961-63v06's Sources outline, whole.
import type { ArchivalCollection, ArchivalNeighbours, SourceExplorer, VolumeSourcesOutline } from '../api/sources';

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

export const collection: ArchivalCollection = {
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
  "catalog": {
    "naId": "2538452",
    "url": "https://catalog.archives.gov/id/2538452"
  },
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
  "pointers": {
    "total": 215,
    "volumes": [
      {
        "count": 1,
        "title": "Foreign Relations of the United States, 1952–1954, Western European Security, Volume V, Part 2",
        "volumeId": "frus1952-54v05p2"
      },
      {
        "count": 5,
        "title": "Foreign Relations of the United States, 1952–1954, Western Europe and Canada, Volume VI, Part 1",
        "volumeId": "frus1952-54v06p1"
      },
      {
        "count": 1,
        "title": "Foreign Relations of the United States, 1952–1954, Germany and Austria, Volume VII, Part 2",
        "volumeId": "frus1952-54v07p2"
      },
      {
        "count": 1,
        "title": "Foreign Relations of the United States, 1952–1954, Eastern Europe; Soviet Union; Eastern Mediterranean, Volume VIII",
        "volumeId": "frus1952-54v08"
      },
      {
        "count": 5,
        "title": "Foreign Relations of the United States, 1952–1954, The Near and Middle East, Volume IX, Part 2",
        "volumeId": "frus1952-54v09p2"
      },
      {
        "count": 1,
        "title": "Foreign Relations of the United States, 1952–1954, Africa and South Asia, Volume XI, Part 2",
        "volumeId": "frus1952-54v11p2"
      },
      {
        "count": 1,
        "title": "Foreign Relations of the United States, 1952–1954, Indochina, Volume XIII, Part 1",
        "volumeId": "frus1952-54v13p1"
      }
    ]
  },
  "previewRowCap": 5,
  "recordGroup": "59",
  "related": [
    {
      "id": "lot:60D530",
      "name": "Daily Summaries: Lot 60 D 530",
      "overlap": 1,
      "recordGroup": "59",
      "repository": "Department of State",
      "sharedVolumeCount": 8
    },
    {
      "id": "txt:department of state|conference files: frc 83-0068",
      "name": "Conference Files: FRC 83–0068",
      "overlap": 1,
      "recordGroup": "59",
      "repository": "Department of State",
      "sharedVolumeCount": 7
    },
    {
      "id": "txt:department of state|io file",
      "name": "IO Files",
      "overlap": 1,
      "repository": "Department of State",
      "sharedVolumeCount": 7
    },
    {
      "id": "txt:eisenhower library|presidential daily appointments record",
      "name": "President’s Daily Appointments Record",
      "overlap": 1,
      "repository": "Eisenhower Library",
      "sharedVolumeCount": 7
    },
    {
      "id": "lot:67D238",
      "name": "EE Files: Lot 67 D 238",
      "overlap": 1,
      "recordGroup": "59",
      "repository": "Department of State",
      "sharedVolumeCount": 6
    },
    {
      "id": "lot:66D225",
      "name": "FE /EA Files: Lot 66 D 225",
      "overlap": 1,
      "recordGroup": "59",
      "repository": "Department of State",
      "sharedVolumeCount": 6
    },
    {
      "id": "txt:eisenhower library|cfep record",
      "name": "CFEP Records",
      "overlap": 1,
      "repository": "Eisenhower Library",
      "sharedVolumeCount": 5
    }
  ],
  "repository": "Department of State",
  "timeline": {
    "eras": [
      {
        "fullLabel": "1951–1954",
        "shortLabel": "’51–54",
        "volumeCount": 14
      },
      {
        "fullLabel": "1955–1957",
        "shortLabel": "’55–57",
        "volumeCount": 22
      },
      {
        "fullLabel": "1958–1960",
        "shortLabel": "’58–60",
        "volumeCount": 21
      },
      {
        "fullLabel": "1961–1963",
        "shortLabel": "’61–63",
        "volumeCount": 19
      },
      {
        "fullLabel": "1964–1968",
        "shortLabel": "’64–68",
        "volumeCount": 7
      }
    ],
    "narrative": "This collection enters the record with the 1951–1954 volumes, peaks across the 1955–1957 volumes, and fades after the 1964–1968 volumes."
  },
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
};

export const dividedCollection: ArchivalCollection = {
  "aliases": [
    "64 D 563",
    "64D563",
    "64–D 563",
    "64–D563",
    "PPS Files",
    "PPS Fixes",
    "PPS Flies",
    "PPS files, Lots 64 D 563",
    "Policy Planning Files",
    "Policy Planning Staff Files",
    "Policy Planning Staff Files 1947–53",
    "State- JCS Meetings"
  ],
  "catalog": {
    "naId": "1136548",
    "url": "https://catalog.archives.gov/id/1136548"
  },
  "children": [
    {
      "name": "Master file of documents",
      "volumeCount": 12
    },
    {
      "name": "Master files of documents",
      "volumeCount": 1
    }
  ],
  "divided": {
    "claimants": [
      {
        "catalogURL": "https://catalog.archives.gov/id/1136548",
        "dateRange": "1947–1962",
        "entryNumbers": [
          "A1 558-D"
        ],
        "naId": "1136548",
        "recordGroup": "59",
        "title": "Chronological Files"
      },
      {
        "catalogURL": "https://catalog.archives.gov/id/1151288",
        "dateRange": "1947–1949",
        "entryNumbers": [
          "A1 558-A"
        ],
        "naId": "1151288",
        "recordGroup": "59",
        "title": "Numbered Staff Studies"
      },
      {
        "catalogURL": "https://catalog.archives.gov/id/1151314",
        "dateRange": "1947–1962",
        "entryNumbers": [
          "A1 558-B"
        ],
        "naId": "1151314",
        "recordGroup": "59",
        "title": "Subject Files"
      },
      {
        "catalogURL": "https://catalog.archives.gov/id/1151315",
        "dateRange": "1947–1962",
        "entryNumbers": [
          "A1 558-CA"
        ],
        "naId": "1151315",
        "recordGroup": "59",
        "title": "Country Files"
      },
      {
        "catalogURL": "https://catalog.archives.gov/id/1151881",
        "dateRange": "1947–1962",
        "entryNumbers": [
          "A1 558-E"
        ],
        "naId": "1151881",
        "recordGroup": "59",
        "title": "Record Copies Files"
      },
      {
        "catalogURL": "https://catalog.archives.gov/id/1154560",
        "dateRange": "1947–1962",
        "entryNumbers": [
          "A1 558-F"
        ],
        "naId": "1154560",
        "recordGroup": "59",
        "title": "Member Chronological Files"
      },
      {
        "catalogURL": "https://catalog.archives.gov/id/1154562",
        "dateRange": "1947–1961",
        "entryNumbers": [
          "A1 558-G"
        ],
        "naId": "1154562",
        "recordGroup": "59",
        "title": "Working Papers"
      },
      {
        "catalogURL": "https://catalog.archives.gov/id/1154583",
        "dateRange": "1947–1962",
        "entryNumbers": [
          "A1 558-H"
        ],
        "naId": "1154583",
        "recordGroup": "59",
        "title": "Meeting Minutes"
      },
      {
        "catalogURL": "https://catalog.archives.gov/id/7432703",
        "dateRange": "1947–1962",
        "entryNumbers": [
          "A1 558-CB"
        ],
        "naId": "7432703",
        "recordGroup": "59",
        "title": "Area Files"
      },
      {
        "catalogURL": "https://catalog.archives.gov/id/7433609",
        "dateRange": "1947–1953",
        "entryNumbers": [
          "A1 558-I"
        ],
        "naId": "7433609",
        "recordGroup": "59",
        "title": "Notes of Meetings"
      },
      {
        "catalogURL": "https://catalog.archives.gov/id/7433611",
        "dateRange": "1947–1962",
        "entryNumbers": [
          "A1 558-J"
        ],
        "naId": "7433611",
        "recordGroup": "59",
        "title": "Records Relating to Meetings with the Department of Defense and the Joint Chiefs of Staff"
      },
      {
        "catalogURL": "https://catalog.archives.gov/id/7433905",
        "dateRange": "1947–1962",
        "entryNumbers": [
          "A1 558-L"
        ],
        "naId": "7433905",
        "recordGroup": "59",
        "title": "Speeches and Articles"
      }
    ],
    "dividedLots": 123,
    "includesRecordsNAID": true
  },
  "documentCount": 0,
  "id": "lot:64D563",
  "lotFileNorm": "64D563",
  "name": "PPS Files, Lot 64 D 563",
  "pointers": {
    "total": 72,
    "volumes": [
      {
        "count": 2,
        "title": "Foreign Relations of the United States, 1945–1950, Emergence of the Intelligence Establishment",
        "volumeId": "frus1945-50Intel"
      },
      {
        "count": 1,
        "title": "Foreign Relations of the United States, 1948, Germany and Austria, Volume II",
        "volumeId": "frus1948v02"
      },
      {
        "count": 2,
        "title": "Foreign Relations of the United States, 1948, Eastern Europe; The Soviet Union, Volume IV",
        "volumeId": "frus1948v04"
      },
      {
        "count": 2,
        "title": "Foreign Relations of the United States, 1948, The Near East, South Asia, and Africa, Volume V, Part 2",
        "volumeId": "frus1948v05p2"
      },
      {
        "count": 1,
        "title": "Foreign Relations of the United States, 1949, Council of Foreign Ministers; Germany and Austria, Volume III",
        "volumeId": "frus1949v03"
      },
      {
        "count": 1,
        "title": "Foreign Relations of the United States, 1949, Eastern Europe; The Soviet Union, Volume V",
        "volumeId": "frus1949v05"
      },
      {
        "count": 1,
        "title": "Foreign Relations of the United States, 1949, The Near East, South Asia, and Africa, Volume VI",
        "volumeId": "frus1949v06"
      }
    ]
  },
  "previewRowCap": 5,
  "recordGroup": "59",
  "related": [
    {
      "id": "txt:eisenhower library|james c. hagerty paper",
      "name": "James C. Hagerty Papers",
      "overlap": 1,
      "repository": "Eisenhower Library",
      "sharedVolumeCount": 11
    },
    {
      "id": "lot:62D333",
      "name": "PSB Files, Lot 62 D 333",
      "overlap": 1,
      "recordGroup": "59",
      "repository": "Department of State",
      "sharedVolumeCount": 10
    },
    {
      "id": "txt:|department of state atomic energy file",
      "name": "Department of State Atomic Energy Files",
      "overlap": 1,
      "sharedVolumeCount": 6
    },
    {
      "id": "lot:60D641",
      "name": "ON Files, Lot 60 D 641",
      "overlap": 1,
      "recordGroup": "59",
      "repository": "Department of State",
      "sharedVolumeCount": 6
    },
    {
      "id": "lot:55D105",
      "name": "Camp Files, Lot 55 D 105",
      "overlap": 1,
      "recordGroup": "59",
      "repository": "Department of State",
      "sharedVolumeCount": 5
    },
    {
      "id": "lot:W130",
      "name": "MSA Telegram Files, Lot W 130",
      "overlap": 1,
      "recordGroup": "59",
      "repository": "Department of State",
      "sharedVolumeCount": 5
    },
    {
      "id": "lot:53D413",
      "name": "Matthews Files, Lot 53 D 413",
      "overlap": 1,
      "recordGroup": "59",
      "repository": "Department of State",
      "sharedVolumeCount": 5
    }
  ],
  "repository": "Department of State",
  "timeline": {
    "eras": [
      {
        "fullLabel": "1941–1947",
        "shortLabel": "’41–47",
        "volumeCount": 6
      },
      {
        "fullLabel": "1948–1950",
        "shortLabel": "’48–50",
        "volumeCount": 17
      },
      {
        "fullLabel": "1951–1954",
        "shortLabel": "’51–54",
        "volumeCount": 26
      },
      {
        "fullLabel": "1955–1957",
        "shortLabel": "’55–57",
        "volumeCount": 1
      }
    ],
    "narrative": "This collection enters the record with the 1941–1947 volumes, peaks across the 1951–1954 volumes, and fades after the 1955–1957 volumes."
  },
  "volumeCount": 0,
  "volumes": [
    {
      "title": "Foreign Relations of the United States, 1945–1950, Emergence of the Intelligence Establishment",
      "volumeId": "frus1945-50Intel"
    },
    {
      "title": "Foreign Relations of the United States, 1946, General; the United Nations, Volume I",
      "volumeId": "frus1946v01"
    },
    {
      "title": "Foreign Relations of the United States, 1947, General; The United Nations, Volume I",
      "volumeId": "frus1947v01"
    },
    {
      "title": "Foreign Relations of the United States, 1947, The British Commonwealth; Europe, Volume III",
      "volumeId": "frus1947v03"
    },
    {
      "title": "Foreign Relations of the United States, 1948, General; the United Nations, Volume I, Part 1",
      "volumeId": "frus1948v01p1"
    },
    {
      "title": "Foreign Relations of the United States, 1948, General; the United Nations, Volume I, Part 2",
      "volumeId": "frus1948v01p2"
    },
    {
      "title": "Foreign Relations of the United States, 1948, Germany and Austria, Volume II",
      "volumeId": "frus1948v02"
    }
  ]
};

export const outline: VolumeSourcesOutline = {
  "rows": [
    {
      "isHeading": false,
      "kind": "prose",
      "text": "Unpublished Sources",
      "depth": 0
    },
    {
      "isHeading": true,
      "kind": "item",
      "crossVolume": [
        {
          "volumeId": "frus1917-72PubDipv08",
          "title": "Foreign Relations of the United States, 1917–1972, Volume VIII, Public Diplomacy, 1969–1972"
        },
        {
          "volumeId": "frus1955-57v01",
          "title": "Foreign Relations of the United States, 1955–1957, Vietnam, Volume I"
        },
        {
          "volumeId": "frus1955-57v04",
          "title": "Foreign Relations of the United States, 1955–1957, Western European Security and Integration, Volume IV"
        },
        {
          "volumeId": "frus1955-57v05",
          "title": "Foreign Relations of the United States, 1955–1957, Austrian State Treaty; Summit and Foreign Ministers Meetings, 1955, Volume V"
        },
        {
          "volumeId": "frus1955-57v24",
          "title": "Foreign Relations of the United States, 1955–1957, Soviet Union, Eastern Mediterranean, Volume XXIV"
        },
        {
          "volumeId": "frus1958-60v03",
          "title": "Foreign Relations of the United States, 1958–1960, National Security Policy; Arms Control and Disarmament, Volume III"
        },
        {
          "volumeId": "frus1958-60v04",
          "title": "Foreign Relations of the United States, 1958–1960, Foreign Economic Policy, Volume IV"
        },
        {
          "volumeId": "frus1958-60v07p1",
          "title": "Foreign Relations of the United States, 1958–1960, Western European Integration and Security, Canada, Volume VII, Part 1"
        },
        {
          "volumeId": "frus1958-60v07p2",
          "title": "Foreign Relations of the United States, 1958–1960, Western Europe, Volume VII, Part 2"
        },
        {
          "volumeId": "frus1958-60v08",
          "title": "Foreign Relations of the United States, 1958–1960, Berlin Crisis, 1958–1959, Volume VIII"
        },
        {
          "volumeId": "frus1958-60v09",
          "title": "Foreign Relations of the United States, 1958–1960, Berlin Crisis, 1959–1960; Germany; Austria, Volume IX"
        },
        {
          "volumeId": "frus1958-60v12",
          "title": "Foreign Relations of the United States, 1958–1960, Near East Region; Iraq; Iran; Arabian Peninsula, Volume XII"
        },
        {
          "volumeId": "frus1958-60v14",
          "title": "Foreign Relations of the United States, 1958–1960, Africa, Volume XIV"
        },
        {
          "volumeId": "frus1958-60v17",
          "title": "Foreign Relations of the United States, 1958–1960, Indonesia, Volume XVII"
        },
        {
          "volumeId": "frus1958-60v18",
          "title": "Foreign Relations of the United States, 1958–1960, Japan; Korea, Volume XVIII"
        },
        {
          "volumeId": "frus1961-63v01",
          "title": "Foreign Relations of the United States, 1961–1963, Volume I, Vietnam, 1961"
        },
        {
          "volumeId": "frus1961-63v05",
          "title": "Foreign Relations of the United States, 1961–1963, Volume V, Soviet Union"
        },
        {
          "volumeId": "frus1961-63v06",
          "title": "Foreign Relations of the United States, 1961–1963, Volume VI, Kennedy-Khrushchev Exchanges"
        },
        {
          "volumeId": "frus1961-63v07",
          "title": "Foreign Relations of the United States, 1961–1963, Volume VII, Arms Control and Disarmament"
        },
        {
          "volumeId": "frus1961-63v08",
          "title": "Foreign Relations of the United States, 1961–1963, Volume VIII, National Security Policy"
        },
        {
          "volumeId": "frus1961-63v09",
          "title": "Foreign Relations of the United States, 1961–1963, Volume IX, Foreign Economic Policy"
        },
        {
          "volumeId": "frus1961-63v10",
          "title": "Foreign Relations of the United States, 1961–1963, Volume X, Cuba, January 1961–September 1962"
        },
        {
          "volumeId": "frus1961-63v11",
          "title": "Foreign Relations of the United States, 1961–1963, Volume XI, Cuban Missile Crisis and Aftermath"
        },
        {
          "volumeId": "frus1961-63v12",
          "title": "Foreign Relations of the United States, 1961–1963, Volume XII, American Republics"
        },
        {
          "volumeId": "frus1961-63v13",
          "title": "Foreign Relations of the United States, 1961–1963, Volume XIII, Western Europe and Canada"
        },
        {
          "volumeId": "frus1961-63v15",
          "title": "Foreign Relations of the United States, 1961–1963, Volume XV, Berlin Crisis, 1962–1963"
        },
        {
          "volumeId": "frus1961-63v16",
          "title": "Foreign Relations of the United States, 1961–1963, Volume XVI, Eastern Europe; Cyprus; Greece; Turkey"
        },
        {
          "volumeId": "frus1961-63v17",
          "title": "Foreign Relations of the United States, 1961–1963, Volume XVII, Near East, 1961–1962"
        },
        {
          "volumeId": "frus1961-63v18",
          "title": "Foreign Relations of the United States, 1961–1963, Volume XVIII, Near East, 1962–1963"
        },
        {
          "volumeId": "frus1961-63v19",
          "title": "Foreign Relations of the United States, 1961–1963, Volume XIX, South Asia"
        },
        {
          "volumeId": "frus1961-63v20",
          "title": "Foreign Relations of the United States, 1961–1963, Volume XX, Congo Crisis"
        },
        {
          "volumeId": "frus1961-63v21",
          "title": "Foreign Relations of the United States, 1961–1963, Volume XXI, Africa"
        },
        {
          "volumeId": "frus1961-63v23",
          "title": "Foreign Relations of the United States, 1961–1963, Volume XXIII: Southeast Asia"
        },
        {
          "volumeId": "frus1961-63v24",
          "title": "Foreign Relations of the United States, 1961–1963, Volume XXIV, Laos Crisis"
        },
        {
          "volumeId": "frus1961-63v25",
          "title": "Foreign Relations of the United States, 1961–1963, Volume XXV, Organization of Foreign Policy; Information Policy; United Nations; Scientific Matters"
        },
        {
          "volumeId": "frus1964-68v02",
          "title": "Foreign Relations of the United States, 1964–1968, Volume II, Vietnam, January–June 1965"
        },
        {
          "volumeId": "frus1964-68v03",
          "title": "Foreign Relations of the United States, 1964–1968, Volume III, Vietnam, June–December 1965"
        },
        {
          "volumeId": "frus1964-68v04",
          "title": "Foreign Relations of the United States, 1964–1968, Volume IV, Vietnam, 1966"
        },
        {
          "volumeId": "frus1964-68v05",
          "title": "Foreign Relations of the United States, 1964–1968, Volume V, Vietnam, 1967"
        },
        {
          "volumeId": "frus1964-68v07",
          "title": "Foreign Relations of the United States, 1964–1968, Volume VII, Vietnam, September 1968–January 1969"
        },
        {
          "volumeId": "frus1964-68v08",
          "title": "Foreign Relations of the United States, 1964–1968, Volume VIII, International Monetary and Trade Policy"
        },
        {
          "volumeId": "frus1964-68v09",
          "title": "Foreign Relations of the United States, 1964–1968, Volume IX, International Development and Economic Defense Policy; Commodities"
        },
        {
          "volumeId": "frus1964-68v10",
          "title": "Foreign Relations of the United States, 1964–1968, Volume X, National Security Policy"
        },
        {
          "volumeId": "frus1964-68v11",
          "title": "Foreign Relations of the United States, 1964–1968, Volume XI, Arms Control and Disarmament"
        },
        {
          "volumeId": "frus1964-68v12",
          "title": "Foreign Relations of the United States, 1964–1968, Volume XII, Western Europe"
        },
        {
          "volumeId": "frus1964-68v13",
          "title": "Foreign Relations of the United States, 1964–1968, Volume XIII, Western Europe Region"
        },
        {
          "volumeId": "frus1964-68v15",
          "title": "Foreign Relations of the United States, 1964–1968, Volume XV, Germany and Berlin"
        },
        {
          "volumeId": "frus1964-68v16",
          "title": "Foreign Relations of the United States, 1964–1968, Volume XVI, Cyprus; Greece; Turkey"
        },
        {
          "volumeId": "frus1964-68v17",
          "title": "Foreign Relations of the United States, 1964–1968, Volume XVII, Eastern Europe"
        },
        {
          "volumeId": "frus1964-68v18",
          "title": "Foreign Relations of the United States, 1964–1968, Volume XVIII, Arab-Israeli Dispute, 1964–1967"
        },
        {
          "volumeId": "frus1964-68v20",
          "title": "Foreign Relations of the United States, 1964–1968, Volume XX, Arab-Israeli Dispute, 1967–1968"
        },
        {
          "volumeId": "frus1964-68v21",
          "title": "Foreign Relations of the United States, 1964–1968, Volume XXI, Near East Region; Arabian Peninsula"
        },
        {
          "volumeId": "frus1964-68v23",
          "title": "Foreign Relations of the United States, 1964–1968, Volume XXIII, Congo, 1960–1968"
        },
        {
          "volumeId": "frus1964-68v24",
          "title": "Foreign Relations of the United States, 1964–1968, Volume XXIV, Africa"
        },
        {
          "volumeId": "frus1964-68v25",
          "title": "Foreign Relations of the United States, 1964–1968, Volume XXV, South Asia"
        },
        {
          "volumeId": "frus1964-68v26",
          "title": "Foreign Relations of the United States, 1964–1968, Volume XXVI, Indonesia; Malaysia-Singapore; Philippines"
        },
        {
          "volumeId": "frus1964-68v28",
          "title": "Foreign Relations of the United States, 1964–1968, Volume XXVIII, Laos"
        },
        {
          "volumeId": "frus1964-68v29p1",
          "title": "Foreign Relations of the United States, 1964–1968, Volume XXIX, Part 1, Korea"
        },
        {
          "volumeId": "frus1964-68v30",
          "title": "Foreign Relations of the United States, 1964–1968, Volume XXX, China"
        },
        {
          "volumeId": "frus1964-68v32",
          "title": "Foreign Relations of the United States, 1964–1968, Volume XXXII, Dominican Republic; Cuba; Haiti; Guyana"
        },
        {
          "volumeId": "frus1969-76v02",
          "title": "Foreign Relations of the United States, 1969–1976, Volume II, Organization and Management of U.S. Foreign Policy, 1969–1972"
        },
        {
          "volumeId": "frus1969-76v03",
          "title": "Foreign Relations of the United States, 1969–1976, Volume III, Foreign Economic Policy; International Monetary Policy, 1969–1972"
        },
        {
          "volumeId": "frus1969-76v04",
          "title": "Foreign Relations of the United States, 1969–1976, Volume IV, Foreign Assistance, International Development, Trade Policies, 1969–1972"
        },
        {
          "volumeId": "frus1969-76v05",
          "title": "Foreign Relations of the United States, 1969–1976, Volume V, United Nations, 1969–1972"
        },
        {
          "volumeId": "frus1969-76v06",
          "title": "Foreign Relations of the United States, 1969–1976, Volume VI, Vietnam, January 1969–July 1970"
        },
        {
          "volumeId": "frus1969-76v07",
          "title": "Foreign Relations of the United States, 1969–1976, Volume VII, Vietnam, July 1970–January 1972"
        },
        {
          "volumeId": "frus1969-76v08",
          "title": "Foreign Relations of the United States, 1969–1976, Volume VIII, Vietnam, January–October 1972"
        },
        {
          "volumeId": "frus1969-76v09",
          "title": "Foreign Relations of the United States, 1969–1976, Volume IX, Vietnam, October 1972–January 1973"
        },
        {
          "volumeId": "frus1969-76v10",
          "title": "Foreign Relations of the United States, 1969–1976, Volume X, Vietnam, January 1973–July 1975"
        },
        {
          "volumeId": "frus1969-76v11",
          "title": "Foreign Relations of the United States, 1969–1976, Volume XI, South Asia Crisis, 1971"
        },
        {
          "volumeId": "frus1969-76v12",
          "title": "Foreign Relations of the United States, 1969–1976, Volume XII, Soviet Union, January 1969–October 1970"
        },
        {
          "volumeId": "frus1969-76v14",
          "title": "Foreign Relations of the United States, 1969–1976, Volume XIV, Soviet Union, October 1971–May 1972"
        },
        {
          "volumeId": "frus1969-76v15",
          "title": "Foreign Relations of the United States, 1969–1976, Volume XV, Soviet Union, June 1972–August 1974"
        },
        {
          "volumeId": "frus1969-76v16",
          "title": "Foreign Relations of the United States, 1969–1976, Volume XVI, Soviet Union, August 1974–December 1976"
        },
        {
          "volumeId": "frus1969-76v17",
          "title": "Foreign Relations of the United States, 1969–1976, Volume XVII, China, 1969–1972"
        },
        {
          "volumeId": "frus1969-76v18",
          "title": "Foreign Relations of the United States, 1969–1976, Volume XVIII, China, 1973–1976"
        },
        {
          "volumeId": "frus1969-76v19p1",
          "title": "Foreign Relations of the United States, 1969–1976, Volume XIX, Part 1, Korea, 1969–1972"
        },
        {
          "volumeId": "frus1969-76v19p2",
          "title": "Foreign Relations of the United States, 1969–1976, Volume XIX, Part 2, Japan, 1969–1972"
        },
        {
          "volumeId": "frus1969-76v20",
          "title": "Foreign Relations of the United States, 1969–1976, Volume XX, Southeast Asia, 1969–1972"
        },
        {
          "volumeId": "frus1969-76v21",
          "title": "Foreign Relations of the United States, 1969–1976, Volume XXI, Chile, 1969–1973"
        },
        {
          "volumeId": "frus1969-76v22",
          "title": "Foreign Relations of the United States, 1969–1976, Volume XXII, Panama, 1973–1976"
        },
        {
          "volumeId": "frus1969-76v25",
          "title": "Foreign Relations of the United States, 1969–1976, Volume XXV, Arab-Israeli Crisis and War, 1973"
        },
        {
          "volumeId": "frus1969-76v26",
          "title": "Foreign Relations of the United States, 1969–1976, Volume XXVI, Arab-Israeli Dispute, 1974–1976"
        },
        {
          "volumeId": "frus1969-76v27",
          "title": "Foreign Relations of the United States, 1969–1976, Volume XXVII, Iran; Iraq, 1973–1976"
        },
        {
          "volumeId": "frus1969-76v28",
          "title": "Foreign Relations of the United States, 1969–1976, Volume XXVIII, Southern Africa"
        },
        {
          "volumeId": "frus1969-76v29",
          "title": "Foreign Relations of the United States, 1969–1976, Volume XXIX, Eastern Europe; Eastern Mediterranean, 1969–1972"
        },
        {
          "volumeId": "frus1969-76v32",
          "title": "Foreign Relations of the United States, 1969–1976, Volume XXXII, SALT I, 1969–1972"
        },
        {
          "volumeId": "frus1969-76v33",
          "title": "Foreign Relations of the United States, 1969–1976, Volume XXXIII, SALT II, 1972–1980"
        },
        {
          "volumeId": "frus1969-76v37",
          "title": "Foreign Relations of the United States, 1969–1976, Volume XXXVII, Energy Crisis, 1974–1980"
        },
        {
          "volumeId": "frus1969-76v38p1",
          "title": "Foreign Relations of the United States, 1969–1976, Volume XXXVIII, Part 1, Foundations of Foreign Policy, 1973–1976"
        },
        {
          "volumeId": "frus1969-76v38p2",
          "title": "Foreign Relations of the United States, 1969–1976, Volume XXXVIII, Part 2, Organization and Management of Foreign Policy; Public Diplomacy, 1973–1976"
        },
        {
          "volumeId": "frus1969-76v39",
          "title": "Foreign Relations of the United States, 1969–1976, Volume XXXIX, European Security"
        },
        {
          "volumeId": "frus1969-76v41",
          "title": "Foreign Relations of the United States, 1969–1976, Volume XLI, Western Europe; NATO, 1969–1972"
        },
        {
          "volumeId": "frus1969-76v42",
          "title": "Foreign Relations of the United States, 1969–1976, Volume XLII, Vietnam: The Kissinger-Le Duc Tho Negotiations, August 1969–December 1973"
        },
        {
          "volumeId": "frus1969-76ve01",
          "title": "Foreign Relations of the United States, 1969–1976, Volume E–1, Documents on Global Issues, 1969–1972"
        },
        {
          "volumeId": "frus1969-76ve02",
          "title": "Foreign Relations of the United States, 1969–1976, Volume E–2, Documents on Arms Control and Nonproliferation, 1969–1972"
        },
        {
          "volumeId": "frus1969-76ve03",
          "title": "Foreign Relations of the United States, 1969–1976, Volume E–3, Documents on Global Issues, 1973–1976"
        },
        {
          "volumeId": "frus1969-76ve04",
          "title": "Foreign Relations of the United States, 1969–1976, Volume E–4, Documents on Iran and Iraq, 1969–1972"
        },
        {
          "volumeId": "frus1969-76ve05p1",
          "title": "Foreign Relations of the United States, 1969–1976, Volume E–5, Part 1, Documents on Sub-Saharan Africa, 1969–1972"
        },
        {
          "volumeId": "frus1969-76ve06",
          "title": "Foreign Relations of the United States, 1969–1976, Volume E–6, Documents on Africa, 1973–1976"
        },
        {
          "volumeId": "frus1969-76ve07",
          "title": "Foreign Relations of the United States, 1969–1976, Volume E–7, Documents on South Asia, 1969–1972"
        },
        {
          "volumeId": "frus1969-76ve08",
          "title": "Foreign Relations of the United States, 1969–1976, Volume E–8, Documents on South Asia, 1973–1976"
        },
        {
          "volumeId": "frus1969-76ve11p1",
          "title": "Foreign Relations of the United States, 1969–1976, Volume E–11, Part 1, Documents on Mexico; Central America; and the Caribbean, 1973–1976"
        },
        {
          "volumeId": "frus1969-76ve11p2",
          "title": "Foreign Relations of the United States, 1969–1976, Volume E–11, Part 2, Documents on South America, 1973–1976"
        },
        {
          "volumeId": "frus1969-76ve12",
          "title": "Foreign Relations of the United States, 1969–1976, Volume E–12, Documents on East and Southeast Asia, 1973–1976"
        },
        {
          "volumeId": "frus1969-76ve14p2",
          "title": "Foreign Relations of the United States, 1969–1976, Volume E–14, Part 2, Documents on Arms Control and Nonproliferation, 1973–1976"
        },
        {
          "volumeId": "frus1969-76ve16",
          "title": "Foreign Relations of the United States, 1969–1976, Volume E–16, Documents on Chile, 1969–1973"
        },
        {
          "volumeId": "frus1977-80v03",
          "title": "Foreign Relations of the United States, 1977–1980, Volume III, Foreign Economic Policy"
        },
        {
          "volumeId": "frus1977-80v06",
          "title": "Foreign Relations of the United States, 1977–1980, Volume VI, Soviet Union"
        },
        {
          "volumeId": "frus1977-80v08",
          "title": "Foreign Relations of the United States, 1977–1980, Volume VIII, Arab-Israeli Dispute, January 1977–August 1978"
        },
        {
          "volumeId": "frus1977-80v13",
          "title": "Foreign Relations of the United States, 1977–1980, Volume XIII, China"
        },
        {
          "volumeId": "frus1977-80v17p3",
          "title": "Foreign Relations of the United States, 1977–1980, Volume XVII, Part 3, North Africa"
        },
        {
          "volumeId": "frus1977-80v21",
          "title": "Foreign Relations of the United States, 1977–1980, Volume XXI, Cyprus; Turkey; Greece"
        },
        {
          "volumeId": "frus1977-80v22",
          "title": "Foreign Relations of the United States, 1977–1980, Volume XXII, Southeast Asia and the Pacific"
        },
        {
          "volumeId": "frus1977-80v23",
          "title": "Foreign Relations of the United States, 1977–1980, Volume XXIII, Mexico, Cuba, and the Caribbean"
        },
        {
          "volumeId": "frus1977-80v26",
          "title": "Foreign Relations of the United States, 1977–1980, Volume XXVI, Arms Control and Nonproliferation"
        },
        {
          "volumeId": "frus1977-80v27",
          "title": "Foreign Relations of the United States, 1977–1980, Volume XXVII, Western Europe"
        },
        {
          "volumeId": "frus1981-88v03",
          "title": "Foreign Relations of the United States, 1981–1988, Volume III, Soviet Union, January 1981–January 1983"
        },
        {
          "volumeId": "frus1981-88v04",
          "title": "Foreign Relations of the United States, 1981–1988, Volume IV, Soviet Union, January 1983–March 1985"
        },
        {
          "volumeId": "frus1981-88v05",
          "title": "Foreign Relations of the United States, 1981–1988, Volume V, Soviet Union, March 1985–October 1986"
        },
        {
          "volumeId": "frus1981-88v06",
          "title": "Foreign Relations of the United States, 1981–1988, Volume VI, Soviet Union, October 1986–January 1989"
        },
        {
          "volumeId": "frus1981-88v13",
          "title": "Foreign Relations of the United States, 1981–1988, Volume XIII, Conflict in the South Atlantic, 1981–1984"
        },
        {
          "volumeId": "frus1981-88v41",
          "title": "Foreign Relations of the United States, 1981–1988, Volume XLI, Global Issues II"
        }
      ],
      "text": "Department of State",
      "depth": 0
    },
    {
      "isHeading": false,
      "kind": "item",
      "text": "Indexed Central Files: Up to January 1963 the Department of State used a central indexed decimal file system for a large part of its records. For this volume the most important decimal files were: 611.61 (general U.S.-Soviet relations); 711.11/KE (President Kennedy); and 761.13: (Soviet Government). In February 1963 the Department of State changed to a subject-numeric central file system, which divided records into broad categories within which were subject and country breakdowns.",
      "depth": 1
    },
    {
      "isHeading": false,
      "kind": "item",
      "text": "Lot Files: Documents from the central files have been supplemented by materials from decentralized office files, the lot files of the Department of State. The two major lot files used in this volume were:",
      "depth": 1
    },
    {
      "entryNumbers": [
        "A1 1590"
      ],
      "text": "Presidential Correspondence: Lot 66 D 204",
      "collection": {
        "volumeCount": 83,
        "id": "lot:66D204"
      },
      "kind": "item",
      "catalogURL": "https://catalog.archives.gov/id/2538452",
      "neighbours": {
        "aliasCollection": "lot:66D204",
        "lotFile": "66 D 204",
        "count": 59,
        "series": "Presidential Correspondence: Lot 66 D 204"
      },
      "depth": 2,
      "isHeading": false
    },
    {
      "isHeading": false,
      "kind": "item",
      "text": "Correspondence of the President and Secretary of State with their counterparts in the Soviet Union, the United Kingdom, France, and the Federal Republic of Germany, 1953-1964.",
      "depth": 3
    },
    {
      "entryNumbers": [
        "A1 5196"
      ],
      "text": "Presidential Correspondence: Lot 77 D 163",
      "collection": {
        "volumeCount": 17,
        "id": "lot:77D163"
      },
      "kind": "item",
      "catalogURL": "https://catalog.archives.gov/id/622626",
      "neighbours": {
        "lotFile": "77 D 163",
        "aliasCollection": "lot:77D163",
        "series": "Presidential Correspondence: Lot 77 D 163",
        "count": 24
      },
      "depth": 2,
      "isHeading": false
    },
    {
      "isHeading": false,
      "kind": "item",
      "text": "Correspondence of Presidents Kennedy and Johnson with the leaders of the Soviet Union, 1961-1964, the so-called Pen Pal correspondence. This lot also contains drafts of messages and memoranda to the President and Secretary of State about the correspondence.",
      "depth": 3
    },
    {
      "isHeading": true,
      "kind": "item",
      "crossVolume": [
        {
          "title": "Foreign Relations of the United States, 1917–1972, Volume VI, Public Diplomacy, 1961–1963",
          "volumeId": "frus1917-72PubDipv06"
        },
        {
          "title": "Foreign Relations of the United States, 1961–1963, Volume I, Vietnam, 1961",
          "volumeId": "frus1961-63v01"
        },
        {
          "title": "Foreign Relations of the United States, 1961–1963, Volume II, Vietnam, 1962",
          "volumeId": "frus1961-63v02"
        },
        {
          "title": "Foreign Relations of the United States, 1961–1963, Volume III, Vietnam, January–August 1963",
          "volumeId": "frus1961-63v03"
        },
        {
          "title": "Foreign Relations of the United States, 1961–1963, Volume IV, Vietnam, August–December 1963",
          "volumeId": "frus1961-63v04"
        },
        {
          "title": "Foreign Relations of the United States, 1961–1963, Volume V, Soviet Union",
          "volumeId": "frus1961-63v05"
        },
        {
          "title": "Foreign Relations of the United States, 1961–1963, Volume VI, Kennedy-Khrushchev Exchanges",
          "volumeId": "frus1961-63v06"
        },
        {
          "title": "Foreign Relations of the United States, 1961–1963, Volume VII, Arms Control and Disarmament",
          "volumeId": "frus1961-63v07"
        },
        {
          "title": "Foreign Relations of the United States, 1961–1963, Volume VIII, National Security Policy",
          "volumeId": "frus1961-63v08"
        },
        {
          "title": "Foreign Relations of the United States, 1961–1963, Volume IX, Foreign Economic Policy",
          "volumeId": "frus1961-63v09"
        },
        {
          "title": "Foreign Relations of the United States, 1961–1963, Volume X, Cuba, January 1961–September 1962",
          "volumeId": "frus1961-63v10"
        },
        {
          "title": "Foreign Relations of the United States, 1961–1963, Volumes X/XI/XII, Microfiche Supplement, American Republics; Cuba 1961–1962; Cuban Missile Crisis and Aftermath",
          "volumeId": "frus1961-63v10-12mSupp"
        },
        {
          "title": "Foreign Relations of the United States, 1961–1963, Volume XI, Cuban Missile Crisis and Aftermath",
          "volumeId": "frus1961-63v11"
        },
        {
          "title": "Foreign Relations of the United States, 1961–1963, Volume XIII, Western Europe and Canada",
          "volumeId": "frus1961-63v13"
        },
        {
          "title": "Foreign Relations of the United States, 1961–1963, Volume XIV, Berlin Crisis, 1961–1962",
          "volumeId": "frus1961-63v14"
        },
        {
          "title": "Foreign Relations of the United States, 1961–1963, Volume XIX, South Asia",
          "volumeId": "frus1961-63v19"
        },
        {
          "title": "Foreign Relations of the United States, 1961–1963, Volume XX, Congo Crisis",
          "volumeId": "frus1961-63v20"
        },
        {
          "title": "Foreign Relations of the United States, 1961–1963, Volume XXI, Africa",
          "volumeId": "frus1961-63v21"
        },
        {
          "title": "Foreign Relations of the United States, 1961–1963, Volume XXII, Northeast Asia",
          "volumeId": "frus1961-63v22"
        },
        {
          "title": "Foreign Relations of the United States, 1961–1963, Volume XXIII: Southeast Asia",
          "volumeId": "frus1961-63v23"
        },
        {
          "title": "Foreign Relations of the United States, 1961–1963, Volume XXIV, Laos Crisis",
          "volumeId": "frus1961-63v24"
        },
        {
          "title": "Foreign Relations of the United States, 1961–1963, Volume XXV, Organization of Foreign Policy; Information Policy; United Nations; Scientific Matters",
          "volumeId": "frus1961-63v25"
        },
        {
          "title": "Foreign Relations of the United States, 1964–1968, Volume I, Vietnam, 1964",
          "volumeId": "frus1964-68v01"
        },
        {
          "title": "Foreign Relations of the United States, 1964–1968, Volume II, Vietnam, January–June 1965",
          "volumeId": "frus1964-68v02"
        },
        {
          "title": "Foreign Relations of the United States, 1964–1968, Volume VIII, International Monetary and Trade Policy",
          "volumeId": "frus1964-68v08"
        },
        {
          "title": "Foreign Relations of the United States, 1964–1968, Volume IX, International Development and Economic Defense Policy; Commodities",
          "volumeId": "frus1964-68v09"
        },
        {
          "title": "Foreign Relations of the United States, 1964–1968, Volume XXIX, Part 2, Japan",
          "volumeId": "frus1964-68v29p2"
        },
        {
          "title": "Foreign Relations of the United States, 1964–1968, Volume XXXIII, Organization and Management of Foreign Policy; United Nations",
          "volumeId": "frus1964-68v33"
        }
      ],
      "text": "John F. Kennedy Library, Boston, Massachusetts",
      "depth": 0
    },
    {
      "neighbours": {
        "series": "National Security Files",
        "aliasCollection": "txt:kennedy library|national security file",
        "repository": "Kennedy Library",
        "count": 23
      },
      "collection": {
        "volumeCount": 30,
        "id": "txt:kennedy library|national security file"
      },
      "catalogURL": "https://catalog.archives.gov/id/1164",
      "text": "National Security Files",
      "depth": 1,
      "kind": "item",
      "isHeading": false
    },
    {
      "collection": {
        "volumeCount": 2,
        "id": "txt:kennedy library|countries serie"
      },
      "isHeading": false,
      "kind": "item",
      "neighbours": {
        "series": "Countries Series, USSR, Khrushchev Correspondence, and Kennedy-Khrushchev Letters",
        "aliasCollection": "txt:kennedy library|countries serie",
        "repository": "Kennedy Library",
        "count": 0
      },
      "text": "Countries Series, USSR, Khrushchev Correspondence, and Kennedy-Khrushchev Letters",
      "depth": 2
    },
    {
      "neighbours": {
        "count": 0,
        "aliasCollection": "txt:kennedy library|presidential appointment book",
        "repository": "Kennedy Library",
        "series": "President’s Appointment Books"
      },
      "collection": {
        "id": "txt:kennedy library|presidential appointment book",
        "volumeCount": 16
      },
      "catalogURL": "https://catalog.archives.gov/id/1154",
      "text": "President’s Appointment Books",
      "depth": 1,
      "kind": "item",
      "isHeading": false
    },
    {
      "isHeading": true,
      "kind": "item",
      "crossVolume": [
        {
          "volumeId": "frus1917-72PubDipv07",
          "title": "Foreign Relations of the United States, 1917–1972, Volume VII, Public Diplomacy, 1964–1968"
        },
        {
          "volumeId": "frus1961-63v01",
          "title": "Foreign Relations of the United States, 1961–1963, Volume I, Vietnam, 1961"
        },
        {
          "volumeId": "frus1961-63v04",
          "title": "Foreign Relations of the United States, 1961–1963, Volume IV, Vietnam, August–December 1963"
        },
        {
          "volumeId": "frus1961-63v05",
          "title": "Foreign Relations of the United States, 1961–1963, Volume V, Soviet Union"
        },
        {
          "volumeId": "frus1961-63v06",
          "title": "Foreign Relations of the United States, 1961–1963, Volume VI, Kennedy-Khrushchev Exchanges"
        },
        {
          "volumeId": "frus1961-63v08",
          "title": "Foreign Relations of the United States, 1961–1963, Volume VIII, National Security Policy"
        },
        {
          "volumeId": "frus1961-63v10",
          "title": "Foreign Relations of the United States, 1961–1963, Volume X, Cuba, January 1961–September 1962"
        },
        {
          "volumeId": "frus1961-63v10-12mSupp",
          "title": "Foreign Relations of the United States, 1961–1963, Volumes X/XI/XII, Microfiche Supplement, American Republics; Cuba 1961–1962; Cuban Missile Crisis and Aftermath"
        },
        {
          "volumeId": "frus1961-63v11",
          "title": "Foreign Relations of the United States, 1961–1963, Volume XI, Cuban Missile Crisis and Aftermath"
        },
        {
          "volumeId": "frus1961-63v13",
          "title": "Foreign Relations of the United States, 1961–1963, Volume XIII, Western Europe and Canada"
        },
        {
          "volumeId": "frus1961-63v14",
          "title": "Foreign Relations of the United States, 1961–1963, Volume XIV, Berlin Crisis, 1961–1962"
        },
        {
          "volumeId": "frus1961-63v15",
          "title": "Foreign Relations of the United States, 1961–1963, Volume XV, Berlin Crisis, 1962–1963"
        },
        {
          "volumeId": "frus1961-63v19",
          "title": "Foreign Relations of the United States, 1961–1963, Volume XIX, South Asia"
        },
        {
          "volumeId": "frus1961-63v20",
          "title": "Foreign Relations of the United States, 1961–1963, Volume XX, Congo Crisis"
        },
        {
          "volumeId": "frus1961-63v21",
          "title": "Foreign Relations of the United States, 1961–1963, Volume XXI, Africa"
        },
        {
          "volumeId": "frus1961-63v23",
          "title": "Foreign Relations of the United States, 1961–1963, Volume XXIII: Southeast Asia"
        },
        {
          "volumeId": "frus1961-63v24",
          "title": "Foreign Relations of the United States, 1961–1963, Volume XXIV, Laos Crisis"
        },
        {
          "volumeId": "frus1961-63v25",
          "title": "Foreign Relations of the United States, 1961–1963, Volume XXV, Organization of Foreign Policy; Information Policy; United Nations; Scientific Matters"
        },
        {
          "volumeId": "frus1964-68v01",
          "title": "Foreign Relations of the United States, 1964–1968, Volume I, Vietnam, 1964"
        },
        {
          "volumeId": "frus1964-68v02",
          "title": "Foreign Relations of the United States, 1964–1968, Volume II, Vietnam, January–June 1965"
        },
        {
          "volumeId": "frus1964-68v03",
          "title": "Foreign Relations of the United States, 1964–1968, Volume III, Vietnam, June–December 1965"
        },
        {
          "volumeId": "frus1964-68v04",
          "title": "Foreign Relations of the United States, 1964–1968, Volume IV, Vietnam, 1966"
        },
        {
          "volumeId": "frus1964-68v05",
          "title": "Foreign Relations of the United States, 1964–1968, Volume V, Vietnam, 1967"
        },
        {
          "volumeId": "frus1964-68v06",
          "title": "Foreign Relations of the United States, 1964–1968, Volume VI, Vietnam, January–August 1968"
        },
        {
          "volumeId": "frus1964-68v07",
          "title": "Foreign Relations of the United States, 1964–1968, Volume VII, Vietnam, September 1968–January 1969"
        },
        {
          "volumeId": "frus1964-68v08",
          "title": "Foreign Relations of the United States, 1964–1968, Volume VIII, International Monetary and Trade Policy"
        },
        {
          "volumeId": "frus1964-68v09",
          "title": "Foreign Relations of the United States, 1964–1968, Volume IX, International Development and Economic Defense Policy; Commodities"
        },
        {
          "volumeId": "frus1964-68v12",
          "title": "Foreign Relations of the United States, 1964–1968, Volume XII, Western Europe"
        },
        {
          "volumeId": "frus1964-68v14",
          "title": "Foreign Relations of the United States, 1964–1968, Volume XIV, Soviet Union"
        },
        {
          "volumeId": "frus1964-68v15",
          "title": "Foreign Relations of the United States, 1964–1968, Volume XV, Germany and Berlin"
        },
        {
          "volumeId": "frus1964-68v17",
          "title": "Foreign Relations of the United States, 1964–1968, Volume XVII, Eastern Europe"
        },
        {
          "volumeId": "frus1964-68v18",
          "title": "Foreign Relations of the United States, 1964–1968, Volume XVIII, Arab-Israeli Dispute, 1964–1967"
        },
        {
          "volumeId": "frus1964-68v19",
          "title": "Foreign Relations of the United States, 1964–1968, Volume XIX, Arab-Israeli Crisis and War, 1967"
        },
        {
          "volumeId": "frus1964-68v20",
          "title": "Foreign Relations of the United States, 1964–1968, Volume XX, Arab-Israeli Dispute, 1967–1968"
        },
        {
          "volumeId": "frus1964-68v21",
          "title": "Foreign Relations of the United States, 1964–1968, Volume XXI, Near East Region; Arabian Peninsula"
        },
        {
          "volumeId": "frus1964-68v22",
          "title": "Foreign Relations of the United States, 1964–1968, Volume XXII, Iran"
        },
        {
          "volumeId": "frus1964-68v23",
          "title": "Foreign Relations of the United States, 1964–1968, Volume XXIII, Congo, 1960–1968"
        },
        {
          "volumeId": "frus1964-68v24",
          "title": "Foreign Relations of the United States, 1964–1968, Volume XXIV, Africa"
        },
        {
          "volumeId": "frus1964-68v25",
          "title": "Foreign Relations of the United States, 1964–1968, Volume XXV, South Asia"
        },
        {
          "volumeId": "frus1964-68v28",
          "title": "Foreign Relations of the United States, 1964–1968, Volume XXVIII, Laos"
        },
        {
          "volumeId": "frus1964-68v29p1",
          "title": "Foreign Relations of the United States, 1964–1968, Volume XXIX, Part 1, Korea"
        },
        {
          "volumeId": "frus1964-68v29p2",
          "title": "Foreign Relations of the United States, 1964–1968, Volume XXIX, Part 2, Japan"
        },
        {
          "volumeId": "frus1964-68v30",
          "title": "Foreign Relations of the United States, 1964–1968, Volume XXX, China"
        },
        {
          "volumeId": "frus1964-68v31",
          "title": "Foreign Relations of the United States, 1964–1968, Volume XXXI, South and Central America; Mexico"
        },
        {
          "volumeId": "frus1964-68v33",
          "title": "Foreign Relations of the United States, 1964–1968, Volume XXXIII, Organization and Management of Foreign Policy; United Nations"
        }
      ],
      "text": "Lyndon B. Johnson Library, Austin, Texas",
      "depth": 0
    },
    {
      "neighbours": {
        "repository": "Johnson Library",
        "aliasCollection": "txt:johnson library|national security file",
        "count": 0,
        "series": "National Security File"
      },
      "collection": {
        "id": "txt:johnson library|national security file",
        "volumeCount": 57
      },
      "catalogURL": "https://catalog.archives.gov/id/567979",
      "text": "National Security File",
      "depth": 1,
      "kind": "item",
      "isHeading": false
    },
    {
      "isHeading": false,
      "kind": "item",
      "neighbours": {
        "repository": "Johnson Library",
        "count": 0,
        "series": "Bundy Files"
      },
      "text": "Bundy Files",
      "depth": 2
    },
    {
      "collection": {
        "volumeCount": 18,
        "id": "txt:johnson library|rusk appointment book"
      },
      "isHeading": false,
      "kind": "item",
      "neighbours": {
        "series": "Rusk Appointment Book",
        "aliasCollection": "txt:johnson library|rusk appointment book",
        "count": 0,
        "repository": "Johnson Library"
      },
      "text": "Rusk Appointment Book",
      "depth": 1
    },
    {
      "isHeading": false,
      "kind": "prose",
      "text": "Published Sources",
      "depth": 0
    },
    {
      "isHeading": false,
      "kind": "bibliography",
      "text": "“Back from the Brink: The Correspondence Between President John F. Kennedy and Chairman Nikita S. Khrushchev on the Cuban Missile Crisis of Autumn 1962,” Problems of Communism, XLI (Spring 1992): pages 1-120.",
      "depth": 0
    },
    {
      "isHeading": false,
      "kind": "bibliography",
      "text": "Beschloss, Michael R. The Crisis Years, Kennedy and Khrushchev, 1960-1963. New York: HarperCollins, 1991.",
      "depth": 0
    },
    {
      "isHeading": false,
      "kind": "bibliography",
      "text": "Claflin, Edward B., ed. The President Wants To Know: Memos from the President’s Office, 1961-1963. New York: Morrow, 1991.",
      "depth": 0
    },
    {
      "isHeading": false,
      "kind": "bibliography",
      "text": "Manchester, William. The Death of a President, November 20-November 25, 1963. New York: Harper-Row, 1967.",
      "depth": 0
    },
    {
      "isHeading": false,
      "kind": "bibliography",
      "text": "Schlesinger, Arthur M., Jr., Robert Kennedy and His Times. Boston: Houghton Mifflin, 1978.",
      "depth": 0
    },
    {
      "isHeading": false,
      "kind": "bibliography",
      "text": "Sulzberger, Cyrus L. The Last of the Giants. New York:Macmillan, 1970.",
      "depth": 0
    },
    {
      "isHeading": false,
      "kind": "bibliography",
      "text": "U.S. Arms Control and Disarmament Agency. Documents on Disarmament, 1961, 1962, and 1963. Washington: U.S. Government Printing Office, 1962-1964.",
      "depth": 0
    },
    {
      "isHeading": false,
      "kind": "bibliography",
      "text": "U.S. Department of State. American Foreign Policy: Current Documents, 1961-1963. Washington: U.S. Government Printing Office, 1965-1967.",
      "depth": 0
    },
    {
      "isHeading": false,
      "kind": "bibliography",
      "text": "———Department of State Bulletin, 1961-1963.",
      "depth": 0
    },
    {
      "isHeading": false,
      "kind": "bibliography",
      "text": "U.S. National Archives and Records Administration. Public Papers of the Presidents of the United States:John F. Kennedy, 1961, 1962, and 1963. Washington: U.S. Government Printing Office, 1962-1964.",
      "depth": 0
    }
  ],
  "volumeId": "frus1961-63v06"
};
