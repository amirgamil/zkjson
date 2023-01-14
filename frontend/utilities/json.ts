export function isJSON(jsonText: any) {
    try {
        JSON.parse(jsonText);
        return true;
    } catch (ex) {
        return false;
    }
}

export const MAX_JSON_LENGTH = 150;

export function JSONStringifyCustom(val: any) {
    return JSON.stringify(
        val,
        (key, value) => (typeof value === "bigint" ? value.toString() : value) // return everything else unchanged
    );
}

export function padJSONString(jsonString: string, desiredLength: number) {
    return jsonString.padEnd(desiredLength, "\0");
}

export type Ascii = number;

export function toAscii(str: string): Ascii[] {
    return Array.from(str).map((_, i) => str.charCodeAt(i));
}

export interface JSON_EL {
    value: string;
    ticked: boolean;
}

export interface JSON_STORE {
    [key: string]: JSON_EL | JSON_STORE;
}

export function isJSONStore(store: JSON_STORE | JSON_EL): store is JSON_STORE {
    return store && !("value" in store);
}

export interface ProofArtifacts {
    publicSignals: string[];
    proof: Object;
}

export const getRecursiveKeyInDataStore = (keys: string[], json: JSON_STORE) => {
    let ptr: JSON_EL | JSON_STORE = json;
    //TODO: handle nesting
    for (var key of keys) {
        if (isJSONStore(ptr) && typeof key === "string" && ptr[key] && ptr[key]) {
            ptr = ptr[key];
        } else {
            return null;
        }
    }
    return ptr;
};

type AttributeQuery = string[];

type JsonCircuitInput = {
    jsonProgram: Ascii[];
    keys: Ascii[][][];
    values: Ascii[][];
    keysOffset: number[][][];
    valuesOffset: number[][];
    hashJsonProgram?: string;
    pubKey?: string[];
    R8?: string[];
    S?: string[];
};

const ATTR_VAL_MAX_LENGTH = 10; // TODO: idk

function padAscii(asciiArr: Ascii[], arrayLen: number): Ascii[] {
    if (asciiArr.length > arrayLen) {
        console.log(`asciiArr ${asciiArr} is longer than the backing array!!!`);
        return asciiArr.slice(0, arrayLen);
    } else {
        while (asciiArr.length < arrayLen) {
            asciiArr.push(0);
        }
        return asciiArr;
    }
}

function padAscii2D(asciiArr: Ascii[][][], stackDepth: number): Ascii[][][] {
    return asciiArr.map((arr) => {
        const innerLength = arr[0].length;
        while (arr.length < stackDepth) {
            let a = new Array();
            for (let i = 0; i < innerLength; i++) {
                a.push(0);
            }
            arr.push(a);
        }
        return arr;
    });
}

function checkAttributes(obj: { [key: string]: any }, attrQueries: AttributeQuery[]): boolean {
    if (attrQueries.length === 0) {
        console.error("Attribute queries empty!");
        return false;
    }

    const depth = attrQueries[0].length;
    const allDepthsEqual = attrQueries.map((x) => x.length === depth).reduce((acc, c) => acc && c);
    if (!allDepthsEqual) {
        console.error("Not all query depths are equal!");
        return false;
    }

    // check that the queried keys exist
    for (const attrQuery of attrQueries) {
        let currObj = obj;
        for (const nestedAttr of attrQuery) {
            if (!(nestedAttr in currObj)) {
                console.error(`Nested attribute ${nestedAttr} of ${attrQuery} not found!`);
                return false;
            }
            currObj = currObj[nestedAttr];
        }
    }
    return true;
}

function extractValuesAscii(obj: Object, attrQueries: AttributeQuery[]): Ascii[][] {
    return attrQueries.map((attrQ) => {
        const value: any = getValue(obj, attrQ);
        if (typeof value === "string") {
            return padAscii(toAscii(`"${value}"`), ATTR_VAL_MAX_LENGTH);
        } else if (typeof value === "number" || typeof value == "boolean") {
            return padAscii(toAscii(value.toString()), ATTR_VAL_MAX_LENGTH);
        } else {
            return [];
        }
    });
}

function getValue(obj: Object, attrQuery: AttributeQuery) {
    return attrQuery.reduce((acc: Record<string, any>, c: string) => acc[c], obj);
}

export const REQUIRED_FIELDS = [
    ["crush", "name"],
    ["crush", "basedScore"],
    ["name"],
    ["balance"],
    ["height"],
    ["superlative"]
];

export function preprocessJson(
    obj: Object,
    jsonProgramSize: number,
): JsonCircuitInput | null {

    const jsonString = JSON.stringify(obj);
    const jsonAscii = padAscii(toAscii(jsonString), jsonProgramSize);
    let stackDepths = [0];
    for (let i = 1; i < jsonString.length; i++) {
        if (jsonString[i] === "{") {
            stackDepths.push(stackDepths[stackDepths.length - 1] + 1);
        } else if (jsonString[i] === "}") {
            stackDepths.push(stackDepths[stackDepths.length - 1] - 1);
        } else {
            stackDepths.push(stackDepths[stackDepths.length - 1]);
        }
    }

    let stackDepth = Math.max(...stackDepths) + 1;

    let keyResults: number[][][] = [];
    let keyOffsets: number[][][] = [];
    let keys: string[][] = [];
    let values: string[] = [];
    let valueOffsets: number[][] = [];
    for (let i = 0; i < stackDepth; i++) {
        keyResults.push([]);
    }

    let colonIndex = -1;
    // check when things are in strings
    while (jsonString.indexOf(":", colonIndex + 1) !== -1) {
        colonIndex = jsonString.indexOf(":", colonIndex + 1);
        let lastQuote = jsonString.lastIndexOf('"', colonIndex);
        let firstQuote = jsonString.lastIndexOf('"', lastQuote - 1);
        let depth = stackDepths[colonIndex];
        keyResults[depth].push([firstQuote, lastQuote]);
        if (jsonString[colonIndex + 1] != "{") {
            // look for comma or ending brace
            let commaIndex = jsonString.indexOf(",", colonIndex);
            let braceIndex = jsonString.indexOf("}", colonIndex);
            let valueResult = [];
            if (commaIndex > -1 && (commaIndex < braceIndex || braceIndex < 0)) {
                valueResult.push(colonIndex + 1);
                valueResult.push(commaIndex - 1);
            } else if (braceIndex > -1 && (braceIndex < commaIndex || commaIndex < 0)) {
                valueResult.push(colonIndex + 1);
                valueResult.push(braceIndex - 1);
            }
            if (valueResult.length > 0) {
                valueOffsets.push(valueResult);
                values.push(jsonString.substring(valueResult[0], valueResult[1] + 1));
                let pathOffsets: number[][] = [];
                let pathKeys: string[] = [];
                for (let i = 0; i <= depth; i++) {
                    console.log("keyresults", keyResults);
                    let arr = keyResults[i];
                    pathOffsets.push(arr[arr.length - 1]);
                    pathKeys.push(jsonString.substring(arr[arr.length - 1][0], arr[arr.length - 1][1] + 1));
                }
                keyOffsets.push(pathOffsets);
                keys.push(pathKeys);
            }
        }
        colonIndex += 1;
    }
    let finalVals = values.map((str) => padAscii(toAscii(str), 40));
    // valueOffsets
    let finalKeys = keys.map((strArr) => {
        let arr = strArr.map((str) => padAscii(toAscii(str), 15));
        while (arr.length < stackDepth) {
            arr.push(new Array(15).fill(0));
        }
        return arr;
    });
    let finalKeyOffsets = keyOffsets.map((offsetArr) => {
        while (offsetArr.length < stackDepth) {
            offsetArr.push([0, 0]);
        }
        return offsetArr;
    });

    const result = {
        jsonProgram: jsonAscii,
        keys: finalKeys,
        values: finalVals,
        keysOffset: finalKeyOffsets,
        valuesOffset: valueOffsets,
    };

    return result;
}

export const createJson = (parsedJsonPtr: any, parsedJsonDataStorePtr: any) => {
    for (var key in parsedJsonPtr) {
        if (["string", "number", "boolean"].includes(typeof parsedJsonPtr[key])) {
            let newLeaf: JSON_EL = {
                value: parsedJsonPtr[key],
                ticked: false,
            };
            parsedJsonDataStorePtr[key] = newLeaf;
        } else {
            let newJsonStore: JSON_STORE = {};
            parsedJsonDataStorePtr[key] = newJsonStore;
            createJson(parsedJsonPtr[key], parsedJsonDataStorePtr[key]);
        }
    }
};

export const checkJsonSchema = (JsonDataStore: JSON_STORE) => {
    

    // Ensure that all the required fields exist;
    var missingFields = [];
    for (var fields of REQUIRED_FIELDS) {
        if (getRecursiveKeyInDataStore(fields, JsonDataStore) === undefined) {
            var fieldStr = "";
            for (var field of fields) {
                fieldStr += field;
                fieldStr += '.';
            }
            missingFields.push(fieldStr.slice(0, length - 1));
        }
    }
    if (missingFields.length) {
        var errorStr = "Unable to generate proof! Missing the following fields: ";
        for (var field of missingFields) {
            errorStr += field;
            errorStr += ", ";
        }
        throw new Error(`${errorStr}`);
    }

}

// let json = {"name":"foobar","value":123,"map":{"a":true}}
// preprocessJson(json, [["map", "a"]], 50, 3).then(res =>
// 	console.dir(res, {depth: null}));
