pragma circom 2.1.0;

include "circomlib/comparators.circom";
include "circomlib/multiplexer.circom";

// include "https://github.com/0xPARC/circom-secp256k1/blob/master/circuits/bigint.circom";

// [
//     {
//         "goal":[]
//     }
// ]

// Specify Stacksize, and compile
stackSize = 10;
squareBracketDepth = 2;
curlyBracketDepth = 1;

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

template jsonVerify(jsonLength) {
    // Verify that we are

    // Use this to track whether we close our brackets.
    signal recursiveDepth[jsonLength];
    signal [jsonLength];
    // Check that the first character is "{"
    // State: InKey
    int (i = 0; i < jsonLength; i++) {

    }
}