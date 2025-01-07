import { getOrCreateContact } from "./agent-contacts";
import { getOrCreateAID, getOrCreateClients} from "./keystore-creation";
import { resolveOobi } from "./oobis";
import { resolveEnvironment, TestEnvironmentPreset } from "./resolve-env";
import { AidInfo, OobiInfo } from "./qvi-data";
import { parseAidInfo } from "./create-aid";

// Pull in arguments from the command line and configuration
const args = process.argv.slice(2);
const env = args[0] as 'local' | 'docker';
const {url, bootUrl, witnessIds, vleiServerUrl, witnessUrls} = resolveEnvironment(env);

export function parseOobiInfo(oobiInfoArg: string) {
    const oobiInfos = oobiInfoArg.split(','); // expect format: "qar1|OOBI,qar2|OOBI,qar3|OOBI,person|OOBI"
    const oobiObjs: OobiInfo[] = oobiInfos.map((aidInfo) => {
        const [position, oobi] = aidInfo.split('|'); // expect format: "qar1|OOBI"
        return {position, oobi};
    });

    const QAR1 = oobiObjs.find((oobiInfo) => oobiInfo.position === 'qar1') as OobiInfo;
    const QAR2 = oobiObjs.find((oobiInfo) => oobiInfo.position === 'qar2') as OobiInfo;
    const QAR3 = oobiObjs.find((oobiInfo) => oobiInfo.position === 'qar3') as OobiInfo;
    const PERSON = oobiObjs.find((oobiInfo) => oobiInfo.position === 'person') as OobiInfo;
    return {QAR1, QAR2, QAR3, PERSON};
}


async function resolveOobis(aidStrArg: string, oobiStrArg: string, environment: TestEnvironmentPreset) {

    const {QAR1, QAR2, QAR3, PERSON} = parseAidInfo(aidStrArg);
    console.log("from oobi-setup");
    console.log(`QAR1: ${JSON.stringify(QAR1)}`);
    console.log(`QAR2: ${JSON.stringify(QAR2)}`);
    console.log(`QAR3: ${JSON.stringify(QAR3)}`);
    console.log(`PERSON: ${JSON.stringify(PERSON)}`);

    const {QAR1: QAR1Oobi, QAR2: QAR2Oobi, QAR3: QAR3Oobi, PERSON: PERSONOobi} = parseOobiInfo(oobiStrArg);
    // create SignifyTS Clients
    const [
        QAR1Client,
        QAR2Client,
        QAR3Client,
        personClient,
    ] = await getOrCreateClients(4, [QAR1.salt, QAR2.salt, QAR3.salt, PERSON.salt], environment);

    // resolve OOBIs for all participants
    await Promise.all([
        getOrCreateContact(QAR1Client, QAR2.name, QAR2Oobi.oobi),
        getOrCreateContact(QAR1Client, QAR3.name, QAR3Oobi.oobi),
        getOrCreateContact(QAR1Client, PERSON.name, PERSONOobi.oobi),

        getOrCreateContact(QAR2Client, QAR1.name, QAR1Oobi.oobi),
        getOrCreateContact(QAR2Client, QAR3.name, QAR3Oobi.oobi),
        getOrCreateContact(QAR2Client, PERSON.name, PERSONOobi.oobi),

        getOrCreateContact(QAR3Client, QAR1.name, QAR1Oobi.oobi),
        getOrCreateContact(QAR3Client, QAR2.name, QAR2Oobi.oobi),
        getOrCreateContact(QAR3Client, PERSON.name, PERSONOobi.oobi),

        getOrCreateContact(personClient, QAR1.name, QAR1Oobi.oobi),
        getOrCreateContact(personClient, QAR2.name, QAR2Oobi.oobi),
        getOrCreateContact(personClient, QAR3.name, QAR3Oobi.oobi),

    ])
}
await resolveOobis(args[1], args[2], env);