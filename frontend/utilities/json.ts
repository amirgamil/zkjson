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
