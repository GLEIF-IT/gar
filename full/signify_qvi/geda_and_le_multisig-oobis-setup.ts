import { getOrCreateContact } from "./agent-contacts";
import { getOrCreateClients } from "./keystore-creation";
import { TestEnvironmentPreset } from "./resolve-env";
import { parseAidInfo } from "./create-aid";
import { OobiInfo } from "./qvi-data";

// Pull in arguments from the command line and configuration
const args = process.argv.slice(2);
const env = args[0] as 'local' | 'docker';

// parse the OOBIs for the GEDA and GIDA multisig AIDs needed for delegation and then LE credential issuance
export function parseOobiInfo(oobiInfoArg: string) {
    const oobiInfos = oobiInfoArg.split(','); // expect format: "gedaMS|OOBI,gidaMS|OOBI"
    const oobiObjs: OobiInfo[] = oobiInfos.map((aidInfo) => {
        const [position, oobi] = aidInfo.split('|'); // expect format: "geda1|OOBI"
        return {position, oobi};
    });

    const GEDA_MS = oobiObjs.find((oobiInfo) => oobiInfo.position === 'gedaMS') as OobiInfo;
    const GIDA_MS = oobiObjs.find((oobiInfo) => oobiInfo.position === 'gidaMS') as OobiInfo;
    return {GEDA_MS, GIDA_MS};
}


async function resolveMultisigOobis(aidStrArg: string, oobiStrArg: string, environment: TestEnvironmentPreset) {
    // create SignifyTS Clients
    const {QAR1, QAR2, QAR3, PERSON} = parseAidInfo(aidStrArg);
    const [
        QAR1Client,
        QAR2Client,
        QAR3Client,
        personClient,
    ] = await getOrCreateClients(4, [QAR1.salt, QAR2.salt, QAR3.salt, PERSON.salt], environment);

    const {GEDA_MS, GIDA_MS} = parseOobiInfo(oobiStrArg);
    await Promise.all([
        getOrCreateContact(QAR1Client, GEDA_MS.position, GEDA_MS.oobi),
        getOrCreateContact(QAR1Client, GIDA_MS.position, GIDA_MS.oobi),

        getOrCreateContact(QAR2Client, GEDA_MS.position, GEDA_MS.oobi),
        getOrCreateContact(QAR2Client, GIDA_MS.position, GIDA_MS.oobi),

        getOrCreateContact(QAR3Client, GEDA_MS.position, GEDA_MS.oobi),
        getOrCreateContact(QAR3Client, GIDA_MS.position, GIDA_MS.oobi),

        getOrCreateContact(personClient, GIDA_MS.position, GIDA_MS.oobi),
    ])
    console.log('Resolved multisig OOBIs');
}
await resolveMultisigOobis(args[1], args[2], env);