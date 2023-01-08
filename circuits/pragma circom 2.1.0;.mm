pragma circom 2.1.0;

include "circomlib/isEqual.circom"
include "circomlib/poseidon.circom";
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
- key[][] (length of key is number of attributes in JSON, inner array is each character)
- value[][] (length of key is number of attributes in JSON, inner array is each character)


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
template Example(jsonLength, attrLength, LARGE_CONSTANT) {
    signal input JSON[jsonLength];
    signal input attribute[attrLength];
    signal input keyOffset[jsonLength];
    signal input valueOffset[jsonLength];
    signal input keys[jsonLength][LARGE_CONSTANT];
    signal output maskedJSON[jsonLength];

    // - 2 to ignore start and end quote

    // constrain length keyOffset == valueOffset == numAttributes you want to select
    // special first offsetStartKey index 0

    // TODO: "/" (quotation marks escaping)
    // TODO: worry about spacing outside keys and values

    // offsetKey0 - 2 == {
    // offsetKeyStart - 2 !== "\"
    // offsetKeyStart - 1 == "
    // offsetKey range is key

    // offsetKeyEnd + 1 == "
    // offsetKeyEnd + 2 == :
    // offsetKeyEnd + 3 = offsetValueStart
    // offsetValueEnd + 1 == "
    // offsetValueEnd + 2 == ,
    // special first offsetEndKey index length - 1
        // offsetKey1 + 3 == }
        
    // part 1 of circuit checking JSON is well structured 
    
    // Inaccurate
    // for(var i = offsetValueStart; i < offsetValueEnd; i++) {
    //     JSON[i] !== '"'
    //     // Anything else to worry about in the middle of the attribute string?
    // }

    // Accurate
    // inVal[0] = 0;
    // for(var i = 1; i < jsonLength; i++) {
    //     start[i] = i == offsetValueStart;
    //     end[i] = i == offsetValueEnd;
    //     inVal[i] = inVal[i - 1] + offsetValueStart - offsetValueEnd;
    //     JSON[i] !== '"' * inVal[i] + (1 - inVal[i]) * 999999999999
    // }

    component[keyOffsetLength][jsonLength] isEqualOps;
    
    for (var i = 0; i < keyOffsetLength; i++) {
        for (var j = keyOffset[i][0]; j < keyOffset[i][1]; j++) {
            // checks offsetKey range is key (key )
            isEqualOps[i][j] === isEqual();
            isEqualOps[i][j].in[0] <== JSON[j];
            isEqualOps[i][j].in[1] <== keys[i][j - keyOffset[i][0]];
            isEqualOps[i][j].out === 1;


        }
        var keyOffsetStart = keyOffset[i][0];
        var keyOffsetEnd = keyOffset[i][0];

        var valueOffsetStart = valueOffset[9]
        var valueOffsetEnd = valueOffset[9]
        // all basic JSON constraints
        JSON[keyOffsetStart - 1] === '"';
        JSON[keyOffsetEnd + 1] === '"';
        JSON[keyOffsetEnd + 2] === ':';
        keyOffset
    }
    
    // part 2
    // a) checking existence of attribute key
    // b) checking existence of attribute value
    // c) extracting value and constraining predicate
}

component main { public [ a ] } = Example();

/* INPUT = {
    "a": "5",
    "b": "77"
} */