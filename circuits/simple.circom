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
- keyOffset[][] (tuple of key start, key end)
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
template Example(jsonLength, attrLength) {
    signal input JSON[jsonLength];
    signal input attribute[attrLength];
    signal input keyOffset[2];
    // signal input valueOffset[2];
    // signal input keys[jsonLength][5];
    // signal output maskedJSON[jsonLength];

    component isEqualStartOps[jsonLength];
    component isEqualEndOps[jsonLength];
    component isEqualNew[jsonLength];
    component multiplexers[jsonLength];
    
    signal inKey[jsonLength + 1];
    signal index[jsonLength + 1];
    inKey[0] <== 0;
    index[0] <== 0;

    for (var j = 0; j < jsonLength; j++) {

        isEqualStartOps[j] = IsEqual();
        isEqualEndOps[j] = IsEqual();
        isEqualNew[j] = IsEqual();

        isEqualStartOps[j].in[0] <== keyOffset[0];
        isEqualStartOps[j].in[1] <== j;
        isEqualEndOps[j].in[0] <== keyOffset[1];
        isEqualEndOps[j].in[1] <== j;

        // inKey is 1 when you're inside the attribute, and 0 when you're outside
        inKey[j + 1] <== inKey[j] + isEqualStartOps[j].out - isEqualEndOps[j].out;
     
        // index inside attribute array
        index[j + 1] <== inKey[j] + index[j];
        
        multiplexers[j] = Multiplexer(1, attrLength);
        for (var i = 0; i < attrLength; i++) {
             multiplexers[j].inp[i][0] <== attribute[i];
        }
        multiplexers[j].sel <== index[j + 1];

        isEqualNew[j].in[0] <== multiplexers[j].out[0];
        isEqualNew[j].in[1] <== JSON[j];
        // Either we are outside the key, or the string must match
        1 === (isEqualNew[j].out * inKey[j + 1]) + (1 - inKey[j + 1]);
    }

    // for (var j = keyOffset[0]; j < keyOffset[1]; j++) {
    //     // isEqualOps[j] = IsEqual();
    //     isEqualOps[j].in[0] <== JSON[j];
    //     isEqualOps[j].in[1] <== 1;
    //     isEqualOps[j].out === 1;
    // }

    // for (var i = 0; i < keyOffsetLength; i++) {
    //     for (var j = keyOffset[i][0]; j < keyOffset[i][1]; j++) {
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
    public [ JSON, attribute, keyOffset ]
} = Example(10, 10);

/* INPUT = {
    "JSON": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
    "attribute": [1, 2],
    "keyOffset": [0, 1]
} */