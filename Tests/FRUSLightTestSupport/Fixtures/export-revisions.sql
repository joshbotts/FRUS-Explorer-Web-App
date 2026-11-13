-- The synthetic export's record of its documents' texts (PLAN's S21f): the kit's content and body hashes of the
-- documents of fixtures/tei and fixtures/own-text it holds, as a Mac's export of those files records them, so that an
-- Import server's comparison of its export with the TEI folder (SPEC's import step 5) finds no change in them.
-- UpdateReviewParityTests.theSyntheticExportRecordsTheFixturesAsTheKitIndexesThem holds each to the kit's indexer at
-- the pin; a pin move that changes one fails there, and prints these lines as the kit gives them.
UPDATE document_revisions SET content_hash = '9b4905a62dce364da7306b8fb67a6bd65cd39c6915b4cfa4fa81ef2b6ae47043', body_hash = '29e7e27be4355f39' WHERE volume_id = 'frus1961-63v06' AND document_id = 'd1';
UPDATE document_revisions SET content_hash = '2a7f4107b9aa6fb828465fced47b58372ecb7dbb1527b1f5ebee53d55ca8d981', body_hash = 'e47488adc531fa5c' WHERE volume_id = 'frus1961-63v06' AND document_id = 'd2';
UPDATE document_revisions SET content_hash = 'd6d423c99d0bd697651e380f4c6872389d152aab15d8d06468e2bb04a9ab1c4a', body_hash = '81b72ee7abcbd67f' WHERE volume_id = 'frus1894Nicaragua' AND document_id = 'd1';
UPDATE document_revisions SET content_hash = 'a5b26d16966215f022fcae48f043b1e60cf7f4dd289317afdb97cad40ef0a44a', body_hash = '562f0be2727aab52' WHERE volume_id = 'frus1969-76v01' AND document_id = 'd1';
UPDATE document_revisions SET content_hash = '1def7da7335a97654e5f4c1710d70ba4895fd210996dbe4754833682a4dcfff4', body_hash = 'ed736bff37389db7' WHERE volume_id = 'frus1969-76v01' AND document_id = 'd2';
UPDATE document_revisions SET content_hash = '510402d18cdec9ee57be9b00e18b74f86fb783053c65df4f4fb7d9eb1aba40f6', body_hash = '999fe52821e35606' WHERE volume_id = 'frus1969-76v01' AND document_id = 'ch1';
UPDATE document_revisions SET content_hash = '169d4c23d3f211db6bf3ba5cf23f39ab8fb1b3ae4063ac4f46d77bc70c2a6688', body_hash = 'ee37193ed6c0bf3f' WHERE volume_id = 'frus1969-76v01' AND document_id = 'comp1';
