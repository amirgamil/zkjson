var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
const ATTR_VAL_MAX_LENGTH = 15; // TODO: idk
const VAL_MAX_LENGTH = 40; // TODO: idk
function toAscii(str) {
    return Array.from(str).map((_, i) => str.charCodeAt(i));
}
function padAscii(asciiArr, arrayLen) {
    if (asciiArr.length > arrayLen) {
        console.log(`asciiArr ${asciiArr} is longer than the backing array!!!`);
        return asciiArr.slice(0, arrayLen);
    }
    else {
        while (asciiArr.length < arrayLen) {
            asciiArr.push(0);
        }
        return asciiArr;
    }
}
function padAscii2D(asciiArr, stackDepth) {
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
function checkAttributes(obj, attrQueries) {
    if (attrQueries.length === 0) {
        console.error("Attribute queries empty!");
        return false;
    }
    const depth = attrQueries[0].length;
    const allDepthsEqual = attrQueries.map((x) => x.length === depth).reduce((acc, c) => acc && c);
    if (!allDepthsEqual) {
        // console.error("Not all query depths are equal!");
        // return false;
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
function extractValuesAscii(obj, attrQueries) {
    return attrQueries.map((attrQ) => {
        const value = getValue(obj, attrQ);
        if (typeof value === "string") {
            return padAscii(toAscii(`"${value}"`), VAL_MAX_LENGTH);
        }
        else if (typeof value === "number" || typeof value == "boolean") {
            return padAscii(toAscii(value.toString()), VAL_MAX_LENGTH);
        }
    });
}
function getValue(obj, attrQuery) {
    return attrQuery.reduce((acc, c) => acc[c], obj);
}
function preprocessJson(obj, attrQueries, jsonProgramSize, stackDepth) {
    return __awaiter(this, void 0, void 0, function* () {
        if (!checkAttributes(obj, attrQueries)) {
            console.error("Attribute check failed!");
            return null;
        }
        const jsonString = JSON.stringify(obj);
        const jsonAscii = padAscii(toAscii(jsonString), jsonProgramSize);
        const queryDepth = attrQueries[0].length;
        const attributes = padAscii2D(attrQueries.map((attrQ) => attrQ.map((nestedAttr) => padAscii(toAscii(`"${nestedAttr}"`), ATTR_VAL_MAX_LENGTH))), stackDepth);
        const keysOffsets = padAscii2D(attrQueries.map((attrQ) => attrQ.map((nestedAttr) => {
            const begin = jsonString.indexOf(`"${nestedAttr}"`);
            const end = begin + nestedAttr.length + 1;
            return [begin, end];
        })), stackDepth);
        // TODO: Undefined behavior if repeated keys¯\_(ツ)_/¯
        const values = extractValuesAscii(obj, attrQueries);
        const valuesOffsets = attrQueries.map((attrQ, i) => {
            // end index of the key + :" (2 chars)
            const begin = keysOffsets[i][queryDepth - 1][1] + 2;
            const value = getValue(obj, attrQ);
            if (typeof value == "string") {
                const end = jsonString.indexOf('"', begin + 1);
                return [begin, end];
            }
            else if (typeof value == "number") {
                let end = begin;
                while (end < jsonString.length) {
                    const currChar = jsonString[end];
                    if (!(currChar >= "0" && currChar <= "9")) {
                        return [begin, end - 1];
                    }
                    end++;
                }
            }
            else if (typeof value == "boolean") {
                return [begin, begin + value.toString().length - 1];
            }
            else {
                console.error("Unsupported value type found while calculating offsets!");
                // return [begin, -1];
            }
        });
        console.log(jsonAscii.splice(0, 50));
        console.log(jsonAscii.splice(0, 50));
        console.log(jsonAscii.splice(0, 50));
        const result = {
            json: jsonAscii,
            keys: attributes,
            values,
            keysOffsets,
            valuesOffsets,
        };
        return result;
    });
}
let json = {
    "name": "shivam",
    "crush": {
        "name": "Amir",
        "basedScore": 10
    },
    "balance": "0",
    "height": "6'5",
    "superlative": "stare at wall for 10 hrs"
};
// {
//     "name": "shivam",
//     "crushName": "amir",
//     "balance": "0",
//     "height": "6'5",
//     "superlative": "stare at wall for 10 hrs"
// }
preprocessJson(json, [["crush", "name"], ["crush", "basedScore"], ["name"], ["balance"], ["height"], ["superlative"]], 150, 2).then((res) => console.dir(res, { depth: null }));
