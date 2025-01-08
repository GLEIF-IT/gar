import { getOrCreateContact } from "./agent-contacts";
import { getOrCreateAID, getOrCreateClients } from "./keystore-creation";
import { resolveEnvironment, TestEnvironmentPreset } from "./resolve-env";
import { parseAidInfo } from "./create-aid";
import { AidInfo } from "./qvi-data";
import signify, { CreateIdentiferArgs, HabState } from "signify-ts";
import { createAIDMultisig } from "./multisig-creation";
import { waitOperation } from "./operations";
import { waitAndMarkNotification } from "./notifications";

const args = process.argv.slice(2);
const env = args[0] as 'local' | 'docker';
const {witnessIds, vleiServerUrl} = resolveEnvironment(env);

async function createQviMultisig(aidInfoArg: string, environment: TestEnvironmentPreset) {
    // get Clients
    const {QAR1, QAR2, QAR3, PERSON} = parseAidInfo(aidInfoArg);
    const [
        QAR1Client,
        QAR2Client,
        QAR3Client,
        personClient,
    ] = await getOrCreateClients(4, [QAR1.salt, QAR2.salt, QAR3.salt, PERSON.salt], environment);
    console.log("Clients created");

    // get AIDs
    const kargsAID = {
        toad: witnessIds.length,
        wits: witnessIds,
    };
    const [
            QAR1Id,
            QAR2Id,
            QAR3Id,
            personId,
    ] = await Promise.all([
        getOrCreateAID(QAR1Client, QAR1.name, kargsAID),
        getOrCreateAID(QAR2Client, QAR2.name, kargsAID),
        getOrCreateAID(QAR3Client, QAR3.name, kargsAID),
        getOrCreateAID(personClient, PERSON.name, kargsAID),
    ]);
    console.log("AIDs created");

    // Create a multisig AID for the QVI.
    // Skip if a QVI AID has already been incepted.
    const QVI_MS_NAME='QVI';
    let qar1, qar2, qar3: HabState;
    try {
        qar1 = await QAR1Client.identifiers().get(QAR1.name);
        qar2 = await QAR2Client.identifiers().get(QAR2.name);
        qar3 = await QAR3Client.identifiers().get(QAR3.name);
    } catch {
        const rstates = [QAR1Id.state, QAR2Id.state, QAR3Id.state];
        const states = rstates;

        const kargsMultisigAID: CreateIdentiferArgs = {
            algo: signify.Algos.group,
            isith: ['1/3', '1/3', '1/3'],
            nsith: ['1/3', '1/3', '1/3'],
            toad: kargsAID.toad,
            wits: kargsAID.wits,
            states: states,
            rstates: rstates,
        };

        kargsMultisigAID.mhab = QAR1Id;
        const multisigAIDOp1 = await createAIDMultisig(
            QAR1Client,
            QAR1Id,
            [QAR2Id, QAR3Id],
            QVI_MS_NAME,
            kargsMultisigAID,
            true
        );
        kargsMultisigAID.mhab = QAR2Id;
        const multisigAIDOp2 = await createAIDMultisig(
            QAR2Client,
            QAR2Id,
            [QAR1Id, QAR3Id],
            QVI_MS_NAME,
            kargsMultisigAID
        );
        kargsMultisigAID.mhab = QAR3Id;
        const multisigAIDOp3 = await createAIDMultisig(
            QAR3Client,
            QAR3Id,
            [QAR1Id, QAR2Id],
            QVI_MS_NAME,
            kargsMultisigAID
        );

        console.log("Creating the QVI multisig AID");
        await Promise.all([
            waitOperation(QAR1Client, multisigAIDOp1),
            waitOperation(QAR2Client, multisigAIDOp2),
            waitOperation(QAR3Client, multisigAIDOp3)
        ]);

        await waitAndMarkNotification(QAR1Client, '/multisig/icp');
        // await waitAndMarkNotification(QAR2Client, '/multisig/icp');
        // await waitAndMarkNotification(QAR3Client, '/multisig/icp');

        const QVIByQAR1 = await QAR1Client.identifiers().get(QVI_MS_NAME);
        const QVIByQAR2 = await QAR2Client.identifiers().get(QVI_MS_NAME);
        const QVIByQAR3 = await QAR3Client.identifiers().get(QVI_MS_NAME);

        console.log(`QVI multisig AID incepted by QAR1: ${QVIByQAR1.prefix}`);
        console.log(`QVI multisig AID incepted by QAR2: ${QVIByQAR2.prefix}`);
        console.log(`QVI multisig AID incepted by QAR3: ${QVIByQAR3.prefix}`);
    }
}
await createQviMultisig(args[1], env)