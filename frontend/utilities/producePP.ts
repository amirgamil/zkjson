import { key } from "localforage";

const numKeys = 6;
const valueLength = 40;
const keysLength = 15;
const pubKeyLength = 256;
const hashJsonProgramLength = 256;

const processAsciiStringArray = (arr: string[]) => {
    var output = "";
    for (var ascii of arr) {
        const number = Number(ascii);
        if (number === 0) {
            break;
        }
        output += String.fromCharCode(number);
    }
    return output;
}

const stackDepth = 2;

export function producePP(pp: string[]) {
    console.log(pp);
    pp.splice(0, 1);
    pp.splice(0, 256);
    pp.splice(0, 1);
    console.log("HH", pp);
    var keys: string[][] = [];
    var values: string[] = [];

    for (var i = 0; i < numKeys; i++) {
        var str: string = processAsciiStringArray(pp.splice(0, valueLength));
        values.push(str);
    }

    for (var i = 0; i < numKeys; i++) {
        var keyList = [];
        for (var j = 0; j < stackDepth; j++) {
            var str: string = processAsciiStringArray(pp.splice(0, keysLength));
            if (str.length) {
                keyList.push(str);
            }
        }
        keys.push(keyList);
    }

    var revealedFields: any = {};

    for (var i = 0; i < values.length; i++) {
        var ptr = revealedFields;
        if (values[i] !== "") {
            for (var j = 0; j < keys[i].length - 1; j++) {
                if (!(keys[i][j] in ptr)) {
                    ptr[keys[i][j]] = {};
                    ptr = ptr[keys[i][j]];
                }
            }
            ptr[keys[i][keys[i].length - 1]] = values[i];
        }
    }
    return revealedFields;
}