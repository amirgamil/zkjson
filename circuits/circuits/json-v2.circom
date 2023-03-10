pragma circom 2.1.0;

include "../node_modules/circomlib/circuits/comparators.circom";
include "../node_modules/circomlib/circuits/multiplexer.circom";
include "./list.circom";

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
        temp3[j] <== JSON[j] - 48;
        accumulator[j + 1] <== temp2[j] + (inKey[j + 1] * temp3[j]);
    }

    out <== accumulator[jsonLength];
}


template StringValueCompare(jsonLength, LARGE_CONSTANT) {
    signal input keyOffset[2];
    signal input JSON[jsonLength];
    signal input attribute[LARGE_CONSTANT];

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
        multiplexers[j] = Multiplexer(1, LARGE_CONSTANT);
        for (var i = 0; i < LARGE_CONSTANT; i++) {
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
template VerifyJSONLayer(jsonLength, attrDepth, attriType, stackDepth) {
    signal input JSON[jsonLength];
    signal input attributes[attrDepth][10];

    // Extract one value
    signal input value[10];
    signal input keysOffset[attrDepth][2];
    signal input valueOffset[2];

    // You are my sunshine
    // My only sunshine
    // You make me happy
    // When I am down 
    // Dadadadadada
    // How much I miss you
    // My sunshine again
    signal inKeys[jsonLength + 1];
    signal enterNewKey[jsonLength];
    signal queryDepth[jsonLength + 1];

    signal stack[jsonLength][stackDepth];
    signal stackPtr[jsonLength];

    inKeys[0] <== 0;
    queryDepth[0] <== 0;
    stackPtr[0] <== 0;

    component eqKeyOffset[jsonLength][attrDepth];
    component eqEnterNewKey[jsonLength];

    for (var i = 0; i < jsonLength; i++) {
        inKeys[i + 1] <== inKeys[i];

        eqEnterNewKey[i] = IsEqual();
        eqEnterNewKey[i].in[0] <== JSON[i];
        eqEnterNewKey[i].in[1] <== 
    }
    // Ensure that stackPtr > queryDepth until the last attribute depth
    // Ensure that stackPtr == queryDepth IF we are enterring a new key

} = VerifyJSONLayer(44, 3, [6, 7, 6], 3, [0, 1, 2], [0, 1, 7]);

/* INPUT = {
	"JSON": [123, 34, 110, 97, 109, 101, 34, 58, 34, 102, 111, 111, 98, 97, 114, 34, 44, 34, 118, 97, 108, 117, 101, 34, 58, 49, 50, 51, 44, 34, 108, 105, 115, 116, 34, 58, 91, 34, 97, 34, 44, 49, 93, 125],
	"attributes": [[34, 110, 97, 109, 101, 34, 0, 0, 0, 0], [34, 118, 97, 108, 117, 101, 34, 0, 0, 0], [34, 108, 105, 115, 116, 34, 0, 0, 0, 0]],
	"values": [[34, 102, 111, 111, 98, 97, 114, 34, 0, 0], [123, 0, 0, 0, 0, 0, 0, 0, 0, 0], [91, 34, 97, 34, 44, 49, 93, 0, 0, 0]],
	"keysOffset": [[1, 6], [17, 23], [29, 34]],
	"valuesOffset": [[8, 15], [25, 27], [36, 42]]
} */
