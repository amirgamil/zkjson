pragma circom 2.1.0;

include "circomlib/comparators.circom";
include "circomlib/multiplexer.circom";
import "./list.circom";

// include "https://github.com/0xPARC/circom-secp256k1/blob/master/circuits/bigint.circom";


/*
Publicly known:

- Public key of signer
- Selected attribute names (also base64)
    (All not mentioned attributes are implied to be redacted)

Private inputs:
- Base64 of JSON
- Hash(base64 of json, secret salt) (like JWT?)
- Signature (Ecdh/ECDSA?)
- keysOffset[][] (tuple of key start, key end)
- valueOffset[][] (tuple of value start, value end)
- key[][] (length of key is number of attributes in JSON, )
*/

// ‘{"name”:“foobar”}’
// array for offsets of keys
    // array of tuples
// array for offsets of values
    // array of tuples
// offsets are for ALL JSON key, value pairs (including ones we are not matching)
// passed input
// keyOffset = [[2, 5]]
// valueOffset = [[8, 13]]
// offsets index of start and end key and value, not including the quotations

// 2 goals 
// 1. make sure json correct
// 2. make sure attribute predicates constrain

// TODO: check there isn't an exploit with offset and attrLength
// template StringCompare(attrLength, jsonLength)

template NumberValueCompare(jsonLength) {
    signal input keyOffset[2];
    signal input JSON[jsonLength];

    signal output out;

    component isEqualStartOps[jsonLength];
    component isEqualEndOps[jsonLength + 1];
    component multiplexers[jsonLength];
    
    signal inKey[jsonLength + 1];
    inKey[0] <== 0;

    // Set the first component to be 0.
    isEqualEndOps[0] = IsEqual();
    isEqualEndOps[0].in[0] <== 0;
    isEqualEndOps[0].in[1] <== 1;

    component stringEnd[jsonLength];
    signal temp1[jsonLength];
    signal temp2[jsonLength];
    signal temp3[jsonLength];
    signal accumulator[jsonLength + 1];

    accumulator[0] <== 0;

    for (var j = 0; j < jsonLength; j++) {
        isEqualStartOps[j] = IsEqual();
        isEqualEndOps[j + 1] = IsEqual();

        isEqualStartOps[j].in[0] <== keyOffset[0];
        isEqualStartOps[j].in[1] <== j;
        isEqualEndOps[j + 1].in[0] <== keyOffset[1];
        isEqualEndOps[j + 1].in[1] <== j;

        // inKey is 1 when you're inside the attribute, and 0 when you're outside
        inKey[j + 1] <== inKey[j] + isEqualStartOps[j].out - isEqualEndOps[j].out;
        // multiply by 10 if in Key
        temp1[j] <== accumulator[j] * inKey[j + 1];
        temp2[j] <== accumulator[j] + temp1[j] * 9;
        // add by the number if inside
        temp3[j] <== JSON[j] - 57;
        accumulator[j + 1] <== temp2[j] + (inKey[j + 1] * temp3[j]);
    }

    out <== accumulator[jsonLength];
}

//[10, 20, 30, 0, 0, 0, 0, 0]
template StringValueCompare(jsonLength) {
    signal input keyOffset[2];
    signal input JSON[jsonLength];
    signal input attribute[10];
    signal output out[10];

    component isEqualStartOps[jsonLength];
    component isEqualEndOps[jsonLength + 1];
    component isEqualNew[jsonLength];
    component multiplexers[jsonLength];
    
    signal inKey[jsonLength + 1];
    signal index[jsonLength + 1];
    inKey[0] <== 0;
    index[0] <== 0;

    // Set the first component to be 0.
    isEqualEndOps[0] = IsEqual();
    isEqualEndOps[0].in[0] <== 0;
    isEqualEndOps[0].in[1] <== 1;

    component stringEnd[jsonLength];
    signal temp[jsonLength];

    var outIndex = 0;
    for (var j = 0; j < jsonLength; j++) {
        isEqualStartOps[j] = IsEqual();
        isEqualEndOps[j + 1] = IsEqual();
        isEqualNew[j] = IsEqual();

        isEqualStartOps[j].in[0] <== keyOffset[0];
        isEqualStartOps[j].in[1] <== j;
        isEqualEndOps[j + 1].in[0] <== keyOffset[1];
        isEqualEndOps[j + 1].in[1] <== j;

        // inKey is 1 when you're inside the attribute, and 0 when you're outside
        inKey[j + 1] <== inKey[j] + isEqualStartOps[j].out - isEqualEndOps[j].out;
     
        // index inside attribute array
        index[j + 1] <== inKey[j] + index[j] - isEqualEndOps[j].out;
        // log(index[j + 1]);
        // log(inKey[j + 1]);
        // log("----");      
        multiplexers[j] = Multiplexer(1, 10);
        for (var i = 0; i < 10; i++) {
             multiplexers[j].inp[i][0] <== attribute[i];
        }
        multiplexers[j].sel <== index[j + 1];

        isEqualNew[j].in[0] <== multiplexers[j].out[0];
        isEqualNew[j].in[1] <== JSON[j];
        // only want to constrain that input is written

        stringEnd[j] = IsEqual();
        stringEnd[j].in[0] <== multiplexers[j].out[0];
        stringEnd[j].in[1] <== 0;
            // Either we are outside the key, or the string must match
        temp[j] <== (isEqualNew[j].out * inKey[j + 1]) + (1 - inKey[j + 1]); 
        1 === temp[j] * (1 - stringEnd[j].out) + stringEnd[j].out;        
    }

}

template StringKeyCompare(attrLength, jsonLength) {
    signal input keyOffset[2];
    signal input JSON[jsonLength];
    signal input attribute[attrLength];
    component isEqualStartOps[jsonLength];
    component isEqualEndOps[jsonLength + 1];
    component isEqualNew[jsonLength];
    component multiplexers[jsonLength];
    
    signal inKey[jsonLength + 1];
    signal index[jsonLength + 1];
    inKey[0] <== 0;
    index[0] <== 0;

    // Set the first component to be 0.
    isEqualEndOps[0] = IsEqual();
    isEqualEndOps[0].in[0] <== 0;
    isEqualEndOps[0].in[1] <== 1;

    // input validation but doesn't check about JSON
    component attrLengthCorrect = IsEqual();
    attrLengthCorrect.in[0] <== keyOffset[1] - keyOffset[0] + 1;
    attrLengthCorrect.in[1] <== attrLength;

    for (var j = 0; j < jsonLength; j++) {
        isEqualStartOps[j] = IsEqual();
        isEqualEndOps[j + 1] = IsEqual();
        isEqualNew[j] = IsEqual();

        isEqualStartOps[j].in[0] <== keyOffset[0];
        isEqualStartOps[j].in[1] <== j;
        isEqualEndOps[j + 1].in[0] <== keyOffset[1];
        isEqualEndOps[j + 1].in[1] <== j;

        // inKey is 1 when you're inside the attribute, and 0 when you're outside
        inKey[j + 1] <== inKey[j] + isEqualStartOps[j].out - isEqualEndOps[j].out;
     
        // index inside attribute array
        index[j + 1] <== inKey[j] + index[j] - isEqualEndOps[j].out;
        // log(index[j + 1]);
        // log(inKey[j + 1]);
        // log("----");      
        multiplexers[j] = Multiplexer(1, attrLength);
        for (var i = 0; i < attrLength; i++) {
             multiplexers[j].inp[i][0] <== attribute[i];
        }
        multiplexers[j].sel <== index[j + 1];

        // LOOP
        isEqualNew[j].in[0] <== multiplexers[j].out[0];
        isEqualNew[j].in[1] <== JSON[j];
        // Either we are outside the key, or the string must match
        1 === (isEqualNew[j].out * inKey[j + 1]) + (1 - inKey[j + 1]);
    }
}

// attrLength is an array of 100
// assuming only 1 attribute right now
// @param attrLengths: array[int]
// @param attriExtractingIndices array[int] array of offset indices to access
template Example(jsonLength, numKeys, attrLengths, numAttriExtracting, attrExtractingIndices, attriTypes) {
    signal input JSON[jsonLength];
    signal input attributes[numKeys][10];
    signal input values[numAttriExtracting][10];
    signal input keysOffset[numKeys][2];
    signal input valuesOffset[numKeys][2];
    // signal input valueOffset[2];
    // signal input keys[jsonLength][5];
    // signal output maskedJSON[jsonLength];

    component attrLengthCorrect[numKeys];
    
    for (var i = 0; i < numKeys; i++) {
        attrLengthCorrect[i] = IsEqual();
        attrLengthCorrect[i].in[0] <== keysOffset[i][1] - keysOffset[i][0] + 1;
        attrLengthCorrect[i].in[1] <== attrLengths[i];
        attrLengthCorrect[i].out === 1;
    }
    
    component stringMatches[numKeys];
    for (var i = 0; i < numKeys; i++) {
        stringMatches[i] = StringKeyCompare(attrLengths[i], jsonLength);
        for (var attIndex = 0; attIndex < attrLengths[i]; attIndex++) {
            stringMatches[i].attribute[attIndex] <== attributes[i][attIndex];
        }
        stringMatches[i].keyOffset <== keysOffset[i];
        stringMatches[i].JSON <== JSON;
    }

    component valueMatchesNumbers[numAttriExtracting];
    component valueMatchesStrings[numAttriExtracting];
    // doesn't actually match arrays, just checks an array is well structured
    component valueMatchesList[numAttriExtracting];
    for (var i = 0; i < numAttriExtracting; i++) {
        // If numbers
        if (attriTypes[i] == 0) {
            valueMatchesStrings[i] = StringValueCompare(jsonLength);
            for (var attIndex = 0; attIndex < 10; attIndex++) {
                valueMatchesStrings[i].attribute[attIndex] <== values[attrExtractingIndices[i]][attIndex];
            }
            valueMatchesStrings[i].keyOffset <== valuesOffset[attrExtractingIndices[i]];
            valueMatchesStrings[i].JSON <== JSON;
        }
        // If strings
        else if (attriTypes[i] == 1) {
            valueMatchesNumbers[i] = NumberValueCompare(jsonLength);
            valueMatchesNumbers[i].keyOffset <== valuesOffset[attrExtractingIndices[i]];
            valueMatchesNumbers[i].JSON <== JSON;
            log(valueMatchesNumbers[i].out);
        // If lists
        // if it's attriTypes is not a 0 or 1, it's a list and the number is the number of the characters
        // in the list (note a list can never have 0 or 1 characters)
        } else {
            valueMatchesList[i] = ListVerify(attriTypes[i]);
            valueMatchesList[i].in = values[attrExtractingIndices[i]];
        }
    }

    component characters[numKeys][6];

    for (var i = 0; i < numKeys; i++) {
        for (var j = 0; j < 6; j ++) {
            // TODO: merge some of these comparisons
            characters[i][j] = StringKeyCompare(1, jsonLength);
            characters[i][j].JSON <== JSON;
        }
    }
  
    for (var i = 0; i < numKeys; i ++) {
        // begin ", end ", :, begin ", end ", ","

        // todo: confusing/inefficient. do single-char comparisons
        characters[i][0].keyOffset <== [keysOffset[i][0] -1, keysOffset[i][0] -1];
        characters[i][0].attribute <== [34];

        characters[i][1].keyOffset <== [keysOffset[i][1] +1, keysOffset[i][1] +1];
        characters[i][1].attribute <== [34];

        characters[i][2].keyOffset <== [valuesOffset[i][0] -1, valuesOffset[i][0] -1];
        characters[i][2].attribute <== [34];

        characters[i][3].keyOffset <== [valuesOffset[i][1]+1, valuesOffset[i][1] +1];
        characters[i][3].attribute <== [34];

        characters[i][4].keyOffset <== [keysOffset[i][1] +2, keysOffset[i][1] +2];
        characters[i][4].attribute <== [58];

        if (i < numKeys - 1) {
            characters[i][5].keyOffset <== [valuesOffset[i][1]+2, valuesOffset[i][1] +2];
            characters[i][5].attribute <== [44];
        }
    }

    for (var i = 0; i < numKeys; i++) {
        keysOffset[i][1] === valuesOffset[i][0] - 4; 
    }
    for (var i = 0; i < numKeys - 1; i++) {
        valuesOffset[i][1] + 4 === keysOffset[i+1][0];
    }

    keysOffset[0][0] === 2;
    JSON[0] === 123;

    // Check that JSON is valid
    valuesOffset[numKeys-1][1] === jsonLength - 3;
    JSON[jsonLength - 1] === 125;
}

component main {
    public [ JSON, keysOffset, attributes ]
} = Example(31, 2, [4, 5], 2, [0, 1], [1, 0]);

/* INPUT = {
	"JSON": [123, 34, 110, 97, 109, 101, 34, 58, 34, 58, 58, 58, 58, 58, 58, 34, 44, 34, 118, 97, 108, 117, 101, 34, 58, 34, 49, 50, 51, 34, 125],
	"attributes": [[110, 97, 109, 101, 0, 0, 0, 0, 0, 0], [118, 97, 108, 117, 101, 0, 0, 0, 0, 0]],
	"values": [[102, 111, 111, 98, 97, 114, 0, 0, 0, 0], [49, 50, 51, 0, 0, 0, 0, 0, 0, 0]],
	"keysOffset": [[2, 5], [18, 22]],
	"valuesOffset": [[9, 14], [26, 28]]
} */