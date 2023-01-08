pragma circom 2.1.0;

include "circomlib/comparators.circom";
include "circomlib/multiplexer.circom";

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

template StringCompare(attrLength, jsonLength) {
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
template Example(jsonLength, numKeys, attrLengths) {
    signal input JSON[jsonLength];
    signal input attributes[numKeys][10];
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
        stringMatches[i] = StringCompare(attrLengths[i], jsonLength);
        for (var attIndex = 0; attIndex < attrLengths[i]; attIndex++) {
            stringMatches[i].attribute[attIndex] <== attributes[i][attIndex];
        }
        stringMatches[i].keyOffset <== keysOffset[i];
        stringMatches[i].JSON <== JSON;
    }

    component characters[numKeys][6];

    for (var i = 0; i < numKeys; i++) {
        for (var j = 0; j < 6; j ++) {
            // TODO: merge some of these comparisons
            characters[i][j] = StringCompare(1, jsonLength);
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

    keysOffset[0][0] === 2;
    JSON[0] === 123;

    valuesOffset[numKeys-1][1] === jsonLength - 3;
    JSON[jsonLength -1] === 125;

    // for (var j = keysOffset[0]; j < keysOffset[1]; j++) {
    //     // isEqualOps[j] = IsEqual();
    //     isEqualOps[j].in[0] <== JSON[j];
    //     isEqualOps[j].in[1] <== 1;
    //     isEqualOps[j].out === 1;
    // }

    // for (var i = 0; i < keyOffsetLength; i++) {
    //     for (var j = keysOffset[i][0]; j < keysOffset[i][1]; j++) {
    //         // checks offsetKey range is key (key )
    //         isEqualOps[i][j] === isEqual();
    //         isEqualOps[i][j].in[0] <== JSON[j];
    //         isEqualOps[i][j].in[1] <== 1;
    //         isEqualOps[i][j].out === 1;
    //     }
    // }

    // part 2
    // a) checking existence of attribute key
    // b) checking existence of attribute value
    // c) extracting value and constraining predicate
}

component main {
    public [ JSON, keysOffset, attributes ]
} = Example(17, 1, [4]);

/* INPUT = {
    "JSON": [123, 34, 110, 97, 109, 101, 34, 58, 34, 102, 111, 111, 98, 97, 114, 34, 125],
    "attributes": [[110, 97, 109, 101, 0, 0, 0, 0, 0, 0]],
    "keysOffset": [[2, 5]],
    "valuesOffset": [[9, 14]]
} */