export function isJSON(jsonText: any) {
    try {
        JSON.parse(jsonText);
        return true;
    } catch (ex) {
        return false;
    }
}

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

export function preprocessJson(
    obj: Object,
    attrQueries: AttributeQuery[],
    jsonProgramSize: number,
    stackDepth: number
): JsonCircuitInput | null {
    if (!checkAttributes(obj, attrQueries)) {
        console.error("Attribute check failed!");
        return null;
    }

    const jsonString = JSON.stringify(obj);
    const jsonAscii = padAscii(toAscii(jsonString), jsonProgramSize);
    const queryDepth = attrQueries[0].length;

    const attributes = padAscii2D(
        attrQueries.map((attrQ) =>
            attrQ.map((nestedAttr) => padAscii(toAscii(`"${nestedAttr}"`), ATTR_VAL_MAX_LENGTH))
        ),
        stackDepth
    );

    const keysOffset = padAscii2D(
        attrQueries.map((attrQ) =>
            attrQ.map((nestedAttr) => {
                const begin = jsonString.indexOf(`"${nestedAttr}"`);
                const end = begin + nestedAttr.length + 1;
                return [begin, end];
            })
        ),
        stackDepth
    );

    // TODO: Undefined behavior if repeated keys¯\_(ツ)_/¯
    const values = extractValuesAscii(obj, attrQueries);
    const valuesOffset: number[][] = attrQueries.map((attrQ, i) => {
        // end index of the key + :" (2 chars)
        const begin = keysOffset[i][queryDepth - 1][1] + 2;
        const value: any = getValue(obj, attrQ);

        if (typeof value == "string") {
            const end = jsonString.indexOf('"', begin + 1);
            return [begin, end];
        } else if (typeof value == "number") {
            let end = begin;
            while (end < jsonString.length) {
                const currChar = jsonString[end];
                if (!(currChar >= "0" && currChar <= "9")) {
                    return [begin, end - 1];
                }
                end++;
            }
            throw new Error("Invalid value type");
        } else if (typeof value == "boolean") {
            return [begin, begin + value.toString().length - 1];
        } else {
            throw new Error("Invalid value type");
        }
    });

    const result = {
        jsonProgram: jsonAscii,
        keys: attributes,
        values,
        keysOffset,
        valuesOffset,
    };

    return result;
}

// let json = {"name":"foobar","value":123,"map":{"a":true}}
// preprocessJson(json, [["map", "a"]], 50, 3).then(res =>
// 	console.dir(res, {depth: null}));
