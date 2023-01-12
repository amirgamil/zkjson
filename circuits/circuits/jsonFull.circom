pragma circom 2.1.2;

include "circomlib/comparators.circom";
include "circomlib/gates.circom";
include "./poseidonLarge.circom";
include "./json.circom";
include "./inRange.circom";

template getCharType() {
  signal input in; // ascii value
  signal output out[10]; // 

  component equals[7];
  for (var i = 0; i < 6; i ++) {
    equals[i] = IsEqual();
    if (i == 0) {
      equals[i].in[0] <== 125;
    }
    else if (i ==1) {
      equals[i].in[0] <== 123;
    }
    else if (i == 2) {
      equals[i].in[0] <== 44;
    }
    else if (i == 3) {
      equals[i].in[0] <== 91;
    }
    else if (i == 4) {
      equals[i].in[0] <== 93;
    }
    else if (i == 5) {
      equals[i].in[0] <== 58;
    }
    equals[i].in[1] <== in;
    out[i] <== equals[i].out;
  }
  equals[6] = IsEqual();
  equals[6].in[0] <== 0;
  equals[6].in[1] <== in;
  out[9] <== equals[6].out;

  component inRange[3];
  for (var i = 0; i < 3; i++) {
    inRange[i] = InRange(8);
    inRange[i].in <== in;
  }
  inRange[0].left <== 48;
  inRange[0].right <== 57;

  inRange[1].left <== 97;
  inRange[1].right <== 122;

  inRange[2].left <== 65;
  inRange[2].right <== 90;

  out[6] <== inRange[0].out;
  out[7] <== inRange[1].out + inRange[2].out;

  component equalsQuote = IsEqual();
  equalsQuote.in[0] <== in;
  equalsQuote.in[1] <== 34;

  out[8] <== equalsQuote.out;
}

// @jsonProgramSize = large constant for max size json
template JsonFull(stackDepth, numKeys, keyLengths, numAttriExtracting, attrExtractingIndices, attriTypes, queryDepth) {
    // string of all the json
    
    var jsonProgramSize = 50;
    signal input jsonProgram[jsonProgramSize];
    signal input hashJsonProgram;
    signal input values[numAttriExtracting][10];
    signal input keys[numAttriExtracting][queryDepth][10];

    signal input keysOffset[numKeys][queryDepth][2];

    component mAnd[jsonProgramSize][numKeys];
     // verify json hashes to provided hash
    component poseidon = PoseidonLarge(jsonProgramSize);
    
    signal input valuesOffset[numKeys][2];
    signal output out;

    // + 1 to allocate empty memory field
    // array of depth where index is 1 corresponding to what depth in the stack we are
    signal jsonStack[jsonProgramSize + 1][stackDepth];

    signal states[jsonProgramSize+1][9];

    signal queryState[numKeys][jsonProgramSize + 2];

    signal temp[numKeys][jsonProgramSize + 1][queryDepth + 1];
    component isZero[numKeys][jsonProgramSize];
    for (var i = 0; i < numKeys; i++) {
      for (var j = 0; j < 2; j++) {
        queryState[i][j] <== 0;
      }
      for (var j = 0; j < jsonProgramSize; j++) {
        temp[i][j][0] <== 1;
        for (var k = 0; k < queryDepth; k++) {
          temp[i][j][k + 1] <== temp[i][j][k] * (keysOffset[i][k][1] - j);
        }

        isZero[i][j] = IsEqual();
        isZero[i][j].in[0] <== temp[i][j][queryDepth];
        isZero[i][j].in[1] <== 0;
        queryState[i][j + 2] <== queryState[i][j + 1] + isZero[i][j].out;
      }
    }

    states[0][0] <== 1;
    for (var i = 1; i < 8; i ++) {
        states[0][i] <== 0;
    }

    component boundaries[jsonProgramSize][2];

    component charTypes[jsonProgramSize];
    component finishedJsonOr[jsonProgramSize];

    jsonStack[0][0] <== 1;
    for (var j = 1; j < stackDepth; j++) {
        jsonStack[0][j] <== 0;
    }

    signal intermediates[jsonProgramSize][11];
    signal more_intermediates[jsonProgramSize][stackDepth][2];
    
    // TODO maybe some offset validation
    for (var i = 0; i < jsonProgramSize; i++) {
        poseidon.in[i] <== jsonProgram[i];
        charTypes[i] = getCharType();

        charTypes[i].in <== jsonProgram[i];
        // charTypes[i].out is 1-hot encoding of type of character
        // states are } { , [ ] : 0-9 a-Z "

        // find new state
        // log(i);
        states[i+1][0] <== 0;

        // intermediates[i][0] <== states[i][0] * charTypes[i].out[1];
        intermediates[i][1] <== states[i][0] * charTypes[i].out[1];
        intermediates[i][2] <== intermediates[i][1] + states[i][7] * charTypes[i].out[2];
        intermediates[i][3] <== intermediates[i][2] + states[i][3] * charTypes[i].out[1];
        states[i+1][1] <==  intermediates[i][3] + states[i][4] * charTypes[i].out[2];

        // Transition to 3
        states[i+1][2] <== states[i][5] * charTypes[i].out[8];

        // Transition to 4
        states[i+1][3] <== states[i][2] * charTypes[i].out[5];

        // Transition to 5
        intermediates[i][4] <== states[i][6] * charTypes[i].out[8];
        intermediates[i][5] <== intermediates[i][4] + states[i][4] * charTypes[i].out[0];
        intermediates[i][6] <== intermediates[i][5] + states[i][7] * charTypes[i].out[0];
        states[i+1][4] <==  intermediates[i][6] + states[i][1] * charTypes[i].out[0];

        // Transition to 6
        intermediates[i][7] <== states[i][1] * charTypes[i].out[8];
        states[i+1][5] <== intermediates[i][7] + states[i][5] * (1 - charTypes[i].out[8]);

        // Transition to 7
        intermediates[i][8] <== states[i][3] * charTypes[i].out[8];
        states[i+1][6] <== intermediates[i][8] + states[i][6] * (1 - charTypes[i].out[8]);

        // Transition to 8
        intermediates[i][9] <== states[i][3] * charTypes[i].out[6];
        states[i+1][7] <==  intermediates[i][9] + states[i][7] * charTypes[i].out[6];

        finishedJsonOr[i] = OR();
        if (i > 0) {
        // 1 if charTypes[i].out[9] or charTypes[i - 1].out9 is 1 0 otherwise
          finishedJsonOr[i].a <== charTypes[i].out[9];
          finishedJsonOr[i].b <== charTypes[i - 1].out[9];
          states[i+1][8] <== finishedJsonOr[i].out;
        } else {
          finishedJsonOr[i].a <== 1;
          finishedJsonOr[i].b <== 1;
        }

        intermediates[i][10] <== jsonStack[i][0] * charTypes[i].out[9];
        jsonStack[i+1][0] <== jsonStack[i][1] * charTypes[i].out[0] + intermediates[i][10];
        more_intermediates[i][stackDepth-1][0] <== jsonStack[i][stackDepth-1] * (1-charTypes[i].out[0]);
        jsonStack[i+1][stackDepth-1] <== more_intermediates[i][stackDepth-1][0] + jsonStack[i][stackDepth-2] * charTypes[i].out[1];

        boundaries[i][0] = IsEqual();
        boundaries[i][0].in[0] <== jsonStack[i][0] * charTypes[i].out[0];
        boundaries[i][0].in[1] <== 0;

        boundaries[i][0].out === 1;

        boundaries[i][1] = IsEqual();
        boundaries[i][1].in[0] <== jsonStack[i][stackDepth-1] * charTypes[i].out[1];
        boundaries[i][1].in[1] <== 0;

        boundaries[i][1].out === 1;

        for (var j = 1; j < stackDepth-1; j++) {
            more_intermediates[i][j][0] <== jsonStack[i][j+1] * charTypes[i].out[0]; // stack++;
            more_intermediates[i][j][1] <== more_intermediates[i][j][0] + jsonStack[i][j-1] * charTypes[i].out[1]; // stack--;
            jsonStack[i+1][j] <== more_intermediates[i][j][1] + jsonStack[i][j] * (1 - charTypes[i].out[0] - charTypes[i].out[1]);
        }
    }

    // In StackMachine,
    // When getting into key, increment queryDepth
    // ['outer', 'inner']
    // When getting into another key after this, ensure that stackPtr is not queryDepth - 1

    var accum[jsonProgramSize];
    signal stackPtr[jsonProgramSize];


    signal isDone[numKeys][jsonProgramSize+1];
    component finished[numKeys][jsonProgramSize];
    for (var i = 0; i < numKeys; i++) {
      isDone[i][0] <== 0;
      for (var j = 0; j < jsonProgramSize; j++) {
        finished[i][j] = IsEqual();
        finished[i][j].in[0] <== keysOffset[i][queryDepth - 1][1];
        finished[i][j].in[1] <== j;
        isDone[i][j+1] <== isDone[i][j] + finished[i][j].out;
      }
    }
    
    for (var i = 0; i < jsonProgramSize; i++) {
      accum[i] = 0;
      for(var j = 0; j < stackDepth; j++) {
        accum[i] = accum[i] + jsonStack[i][j] * j;
      }
      stackPtr[i] <-- accum[i];
    }

    component depthComparison[numKeys][jsonProgramSize];
    var BIG_NUMBER = 10000;
    // stpr never goes below querydepth
    // queryState keeps going up (increments on each closing quote of the key)
    // stackPtr = depth of stack (increments and decrements on opening and closing curly brace)
    // want stackPtr to not be too small (i.e didn't exit an inner json)
    // depth comparison is looking at 2 steps ahead 
    for (var i = 0; i < numKeys; i++) {
      for (var j = 0; j < jsonProgramSize - 2; j++) {
        depthComparison[i][j] = IsEqual();
        // isDone is 0 when before val of inner json you're extracting and 1 after
        depthComparison[i][j].in[0] <== queryState[i][j] + BIG_NUMBER * isDone[i][j + 1];
        // want to check the thing above is less than the thing below
        // isLessThan same as stackPtr[j+1] != depth - 1
        // concerned there is a correctness issue s
        // - 2 because can only every decrement by 1
        depthComparison[i][j].in[1] <== stackPtr[j + 1];
        depthComparison[i][j].out === 0;
      }
    }
    // '{"circom":{"a": "b"}'
    //  queryState: 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, // increments at closing
    //  stackPtr:   1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2

    // Ensuring each offset's stackpointer correctly
    // checks depth = stackptr - 1
    component multis[numKeys][queryDepth];
    for (var i = 0; i < numKeys; i++) {
      for (var j = 0; j < queryDepth; j++) {
        multis[i][j] = Multiplexer(1, jsonProgramSize);
        for (var k = 0; k < jsonProgramSize; k++) {
          multis[i][j].inp[k][0] <== stackPtr[k];
        }
        multis[i][j].sel <== keysOffset[i][j][1];
        j === multis[i][j].out[0] - 1;
      }
    }

    // extract nested keys
    component stringMatches[numKeys][queryDepth];
    for (var i = 0; i < numKeys; i++) {
      for (var j = 0; j < queryDepth; j++) {
        stringMatches[i][j] = StringKeyCompare(keyLengths[i], jsonProgramSize);
        for (var attIndex = 0; attIndex < keyLengths[i]; attIndex++) {
            stringMatches[i][j].attribute[attIndex] <== keys[i][j][attIndex];
        }
        stringMatches[i][j].keyOffset <== keysOffset[i][j];
        stringMatches[i][j].JSON <== jsonProgram;
      }
    }
    for (var i = 0; i < numKeys; i++) {
      keysOffset[i][queryDepth - 1][1] === valuesOffset[i][0] - 2;
    }

    // extracting
    component valueMatchesNumbers[numAttriExtracting];
    component valueMatchesStrings[numAttriExtracting];
    component valueMatchesList[numAttriExtracting];
    for (var i = 0; i < numAttriExtracting; i++) {
      // If numbers
      if (attriTypes[attrExtractingIndices[i]] == 0) {
          valueMatchesStrings[i] = StringValueCompare(jsonProgramSize, 10);
          for (var attIndex = 0; attIndex < 10; attIndex++) {
              valueMatchesStrings[i].attribute[attIndex] <== values[attrExtractingIndices[i]][attIndex];
          }
          valueMatchesStrings[i].keyOffset <== valuesOffset[attrExtractingIndices[i]];
          valueMatchesStrings[i].JSON <== jsonProgram;
      }
      // If strings
      else if (attriTypes[attrExtractingIndices[i]] == 1) {
          valueMatchesNumbers[i] = NumberValueCompare(jsonProgramSize);
          valueMatchesNumbers[i].keyOffset <== valuesOffset[attrExtractingIndices[i]];
          valueMatchesNumbers[i].JSON <== jsonProgram;
          // if values is a number it will be the first element of the array
          valueMatchesNumbers[i].out === values[attrExtractingIndices[i]][0];
          // If lists
          // if it's attriTypes is not a 0 or 1, it's a list and the number is the number of the characters
          // in the list (note a list can never have 0 or 1 characters)
      }
    }

   
    // assert hash is the same as what is passed in (including trailing 0s)
    poseidon.out === hashJsonProgram;

    out <== jsonStack[jsonProgramSize][0] * (states[jsonProgramSize][4] + states[jsonProgramSize][8]);
}

component main { public [ jsonProgram, keysOffset ] } = JsonFull(4, 1, [6, 7, 3], 1, [0], [0], 2);

// {"name":"foobar","value":123,"map":{"a":"1"}}

/* INPUT = {
  "hashJsonProgram": "10058416048496861476264053793475873949645935904167570960039020625334949516197",
	"jsonProgram": [123, 34, 110, 97, 109, 101, 34, 58, 34, 102, 111, 111, 98, 97, 114, 34, 44, 34, 118, 97, 108, 117, 101, 34, 58, 49, 50, 51, 44, 34, 109, 97, 112, 34, 58, 123, 34, 97, 34, 58, 34, 49, 34, 125, 125, 0, 0, 0, 0, 0],
	"keys": [[[34, 109, 97, 112, 34, 0, 0, 0, 0, 0], [34, 97, 34, 0, 0, 0, 0, 0, 0, 0]]],
	"values": [[34, 49, 34, 0, 0, 0, 0, 0, 0, 0]],
	"keysOffset": [[[29, 33], [36, 38]]],
	"valuesOffset": [[40, 42]]
} */
