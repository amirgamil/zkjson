pragma circom 2.1.0;

include "../node_modules/circomlib/circuits/comparators.circom";
include "../node_modules/circomlib/circuits/eddsa.circom";
include "../node_modules/circomlib/circuits/bitify.circom";
include "../node_modules/circomlib/circuits/gates.circom";
include "./poseidonLarge.circom";
include "./json.circom";
include "./charType.circom";

// @jsonProgramSize = large constant for max size json
template JsonFull(stackDepth, numKeys, keyLengths, attrExtractingIndices, attriTypes, queryDepths) {
    // string of all the json
    
    var jsonProgramSize = 50;
    var jsonProgramSizeBits = 400;
    
    signal input pubKey[256];
    signal hashbits[254];
    signal input R8[256];
    signal input S[256];



    signal input jsonProgram[jsonProgramSize];
    signal input hashJsonProgram;
    signal input values[numKeys][10];
    signal input keys[numKeys][stackDepth][10];

    signal input keysOffset[numKeys][stackDepth][2];

    component mAnd[jsonProgramSize][numKeys];
     // verify json hashes to provided hash
    // component poseidon = PoseidonLarge(jsonProgramSize);
    
    signal input valuesOffset[numKeys][2];
    signal output out;

    component num2bits[jsonProgramSize];

    component hash2bits = Num2Bits(254);

    for (var i = 0; i < jsonProgramSize; i++) {
      num2bits[i] = Num2Bits(7);
      num2bits[i].in <== jsonProgram[i];
    }

    hash2bits.in <== hashJsonProgram;

    // first constrain that passed in JSON is indeed what was signed
    //TODO: change when we change jsonProgramSize
    component eddsa = EdDSAVerifier(254);
    eddsa.A <== pubKey;
    eddsa.R8 <== R8;
    eddsa.S <== S;
    eddsa.msg  <== hash2bits.out;

    // + 1 to allocate empty memory field
    // array of depth where index is 1 corresponding to what depth in the stack we are
    signal jsonStack[jsonProgramSize + 1][stackDepth][2];

    signal states[jsonProgramSize+1][20];

    signal queryState[numKeys][jsonProgramSize + 2];

    signal temp[numKeys][jsonProgramSize + 1][stackDepth + 1];
    component isZero[numKeys][jsonProgramSize];
    for (var i = 0; i < numKeys; i++) {
      for (var j = 0; j < 2; j++) {
        queryState[i][j] <== 0;
      }
      for (var j = 0; j < jsonProgramSize; j++) {
        temp[i][j][0] <== 1;
        for (var k = 0; k < queryDepths[i]; k++) {
          temp[i][j][k + 1] <== temp[i][j][k] * (keysOffset[i][k][1] - j);
        }

        isZero[i][j] = IsEqual();
        isZero[i][j].in[0] <== temp[i][j][queryDepths[i]];
        isZero[i][j].in[1] <== 0;
        queryState[i][j + 2] <== queryState[i][j + 1] + isZero[i][j].out;
      }
    }

    states[0][0] <== 1;
    for (var i = 1; i < 19; i ++) {
        states[0][i] <== 0;
    }

    // boundaries to prevent overflow
    component boundariesOverflow[jsonProgramSize];
    // boundaries to prevent popping empty stack
    component boundariesBottom[jsonProgramSize][stackDepth];
    component boundariesCheck[jsonProgramSize];

    component charTypes[jsonProgramSize];
    component finishedJsonOr[jsonProgramSize];

    for (var j = 0; j < stackDepth; j++) {
        jsonStack[0][j][0] <== 0;
        jsonStack[0][j][1] <== 0;
    }

    signal intermediates[jsonProgramSize][8];
    signal preedge[jsonProgramSize][2];
    signal more_intermediates[jsonProgramSize][stackDepth][2][2];
    signal extra_intermediates[jsonProgramSize][2];
    
    // TODO maybe some offset validation
    // state 10: after processing t
    // state 11: --- tr
    // state 12: --- tru
    // state 13: f
    // state 14: fa
    // state 15: fal
    // state 16: fals
    for (var i = 0; i < jsonProgramSize; i++) {
        // poseidon.in[i] <== jsonProgram[i];
        charTypes[i] = getCharType();

        charTypes[i].in <== jsonProgram[i];

        var isComma = charTypes[i].out[2];
        var isSquareBracketsOpen = charTypes[i].out[3];
        var isSquareBracketsClosed = charTypes[i].out[4];

        // Array
        states[i + 1][16] <== (states[i][3] + states[i][16] + states[i][17]) * isSquareBracketsOpen;

        states[i + 1][17] <== states[i][18] * isComma;

        // Transition to 5
        intermediates[i][0] <== states[i][6] * charTypes[i].out[8];

        intermediates[i][1] <== intermediates[i][0] + (states[i][4] + states[i][7]) * (charTypes[i].out[0] + charTypes[i].out[4]);
        intermediates[i][2] <== intermediates[i][1] + (states[i][11] + states[i][15]) * charTypes[i].out[13];
        intermediates[i][3] <== intermediates[i][2] + (states[i][18] + states[i][16]) * isSquareBracketsClosed;
        preedge[i][0] <== intermediates[i][3] + states[i][1] * charTypes[i].out[0];

        // Allow transitions into strings, numbers, booleans, and itself from 16 and 18

        // BOOLEANS

        states[i+1][9] <== (states[i][3] + states[i][16] + states[i][18]) * charTypes[i].out[10];
        states[i+1][10] <== states[i][9] * charTypes[i].out[11];
        states[i+1][11] <== states[i][10] * charTypes[i].out[12];
        // TODO: go from 12 -> finished state 

        states[i+1][12] <== (states[i][3] + states[i][16] + states[i][18]) * charTypes[i].out[14];
        states[i+1][13] <== states[i][12] * charTypes[i].out[15];
        states[i+1][14] <== states[i][13] * charTypes[i].out[16];
        states[i+1][15] <== states[i][14] * charTypes[i].out[17];
        // TODO: go from 16 -> finished state


        // charTypes[i].out is 1-hot encoding of type of character
        // states are } { , [ ] : 0-9 a-Z "

        // find new state
        states[i+1][0] <== 0;

        // intermediates[i][0] <== states[i][0] * charTypes[i].out[1];
        intermediates[i][4] <== (states[i][0] + states[i][3]) * charTypes[i].out[1];
        states[i+1][1] <==  intermediates[i][4] + (states[i][7] + states[i][4]) * charTypes[i].out[2];

        // Transition to 3
        states[i+1][2] <== states[i][5] * charTypes[i].out[8];

        // Transition to 4
        states[i+1][3] <== states[i][2] * charTypes[i].out[5];

        // Transition to 5
        intermediates[i][5] <== states[i][6] * charTypes[i].out[8];
        intermediates[i][6] <== intermediates[i][5] + (states[i][1] + states[i][4] + states[i][7]) * charTypes[i].out[0];
        intermediates[i][7] <== intermediates[i][6] + (states[i][11] + states[i][15]) * charTypes[i].out[13];
        preedge[i][1] <== intermediates[i][7] + (states[i][16] + states[i][18]) * isSquareBracketsClosed;
        
        // Transition to 6
        states[i+1][5] <== (states[i][1] - states[i][5]) * charTypes[i].out[8] + states[i][5];

        // Transition to 7
        states[i+1][6] <== states[i][6] + (states[i][3] + states[i][16] + states[i][18] - states[i][6]) * charTypes[i].out[8];

        // Transition to 8
        states[i+1][7] <==  (states[i][3] + states[i][7] + states[i][16] + states[i][18]) * charTypes[i].out[6];


        finishedJsonOr[i] = OR();
        if (i > 0) {
        // 1 if charTypes[i].out[9] or charTypes[i - 1].out9 is 1 0 otherwise
          finishedJsonOr[i].a <== charTypes[i].out[9];
          finishedJsonOr[i].b <== charTypes[i - 1].out[9];
          states[i+1][8] <== finishedJsonOr[i].out;
        } else {
          finishedJsonOr[i].a <== 1;
          finishedJsonOr[i].b <== 1;
          states[i+1][8] <== 0;
        }

        // If '{' push 1
        // If '}' pop
        // If not 0 stay
        var notZeroOrBrackets = (1 - charTypes[i].out[0] - charTypes[i].out[1] - charTypes[i].out[3] - charTypes[i].out[4]);
        var isClosingBracket = charTypes[i].out[0] + charTypes[i].out[4];
        var isOpeningbracket = charTypes[i].out[1];
        var isFinished = charTypes[i].out[9];

        for (var j = 0; j < 2; j++) {
          extra_intermediates[i][j] <== jsonStack[i][0][j] * notZeroOrBrackets;
          more_intermediates[i][stackDepth - 1][0][j] <== jsonStack[i][stackDepth - 1][0] * (1 - isClosingBracket);
          jsonStack[i + 1][stackDepth - 1][j] <== more_intermediates[i][stackDepth - 1][0][j] + jsonStack[i][stackDepth - 2][0] * charTypes[i].out[1];
        }
        jsonStack[i + 1][0][0] <== jsonStack[i][1][0] * isClosingBracket + extra_intermediates[i][0] + charTypes[i].out[1];
        jsonStack[i + 1][0][1] <== jsonStack[i][1][1] * isClosingBracket + extra_intermediates[i][1] + charTypes[i].out[3];

        // Check that stack is not overflown | replicate the same for '[]'
        boundariesOverflow[i] = IsEqual();
        boundariesOverflow[i].in[0] <== jsonStack[i][stackDepth-1][0] * (charTypes[i].out[1] + charTypes[i].out[3]);
        boundariesOverflow[i].in[1] <== 0;
        boundariesOverflow[i].out === 1;

        for (var k = 0; k < 2; k++) {
          for (var j = 1; j < stackDepth - 1; j++) {
            more_intermediates[i][j][0][k] <== jsonStack[i][j + 1][k] * (charTypes[i].out[0] + charTypes[i].out[4]); // stack++;
            more_intermediates[i][j][1][k] <== more_intermediates[i][j][0][k] + jsonStack[i][j - 1][k] * (charTypes[i].out[1] + charTypes[i].out[3]); // stack--;
            jsonStack[i+1][j][k] <== more_intermediates[i][j][1][k] + jsonStack[i][j][k] * (1 - charTypes[i].out[0] - charTypes[i].out[1] - charTypes[i].out[3] - charTypes[i].out[4]);
          }
        }

        // Ensures that the stack is never empty
        var signals;
        for (var j = 0; j < stackDepth; j++) {
          signals += jsonStack[i + 1][j][0];
        }
        boundariesCheck[i] = IsEqual();
        boundariesCheck[i].in[0] <== 0;
        boundariesCheck[i].in[1] <== signals;

        states[i+1][4] <== preedge[i][1] * jsonStack[i + 1][0][0];
        states[i+1][18] <== preedge[i][0] * jsonStack[i + 1][0][1];
        states[i+1][19] <== states[i][4] * boundariesCheck[i].out;

        var sum;
        for (var j = 0; j < 20; j++) {
          sum += states[i+1][j];
        }
        1 === sum;
    }
    for (var i = 1; i < jsonProgramSize; i++) {
      boundariesCheck[i - 1].out === charTypes[i].out[9];
    }

    // In StackMachine,
    // When getting into key, increment queryDepth
    // ['outer', 'inner']
    // When getting into another key after this, ensure that stackPtr is not queryDepth - 1

    signal isDone[numKeys][jsonProgramSize+1];
    component finished[numKeys][jsonProgramSize];
    for (var i = 0; i < numKeys; i++) {
      isDone[i][0] <== 0;
      for (var j = 0; j < jsonProgramSize; j++) {
        finished[i][j] = IsEqual();
        finished[i][j].in[0] <== keysOffset[i][queryDepths[i] - 1][1];
        finished[i][j].in[1] <== j;
        isDone[i][j+1] <== isDone[i][j] + finished[i][j].out;
      }
    }

    signal stackPtr[jsonProgramSize];
    for (var i = 0; i < jsonProgramSize; i++) {
      var sum = 0;
      for(var j = 0; j < stackDepth; j++) {
        sum += jsonStack[i][j][0]; // Ensure to add when we include '{}' in our jsonStack represent
        sum += jsonStack[i][j][1]; // Ensure to add when we include '[]' in our jsonStack represent
      }
      stackPtr[i] <-- sum;
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
    component multis[numKeys][stackDepth];
    for (var i = 0; i < numKeys; i++) {
      for (var j = 0; j < queryDepths[i]; j++) {
        multis[i][j] = Multiplexer(1, jsonProgramSize);
        for (var k = 0; k < jsonProgramSize; k++) {
          multis[i][j].inp[k][0] <== stackPtr[k];
        }
        multis[i][j].sel <== keysOffset[i][j][1];
        j === multis[i][j].out[0] - 1;
      }
    }

    // extract nested keys
    component stringMatches[numKeys][stackDepth];
    for (var i = 0; i < numKeys; i++) {
      for (var j = 0; j < queryDepths[i]; j++) {
        stringMatches[i][j] = StringKeyCompare(keyLengths[i][j], jsonProgramSize);
        for (var attIndex = 0; attIndex < keyLengths[i][j]; attIndex++) {
            stringMatches[i][j].attribute[attIndex] <== keys[i][j][attIndex];
        }
        stringMatches[i][j].keyOffset <== keysOffset[i][j];
        stringMatches[i][j].JSON <== jsonProgram;
      }
    }
    for (var i = 0; i < numKeys; i++) {
      keysOffset[i][queryDepths[i] - 1][1] === valuesOffset[i][0] - 2;
    }

    // extracting
    component valueMatchesNumbers[numKeys];
    component valueMatchesStrings[numKeys];
    component valueMatchesList[numKeys];
    for (var i = 0; i < numKeys; i++) {
      // If numbers
      if (attriTypes[attrExtractingIndices[i]] != 1) {
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
      // TODO: check for 2s
    }
   
    // assert hash is the same as what is passed in (including trailing 0s)
    // poseidon.out === hashJsonProgram;

    component finalCheck = IsEqual();
    finalCheck.in[0] <== stackPtr[jsonProgramSize - 1];
    finalCheck.in[1] <== 0;
    out <== finalCheck.out * (states[jsonProgramSize][4] + states[jsonProgramSize][8]);
}

component main { public [ jsonProgram, keysOffset, pubKey, R8, S ] } = JsonFull(3, 1, [[5, 3]], [0], [2], [2]);

// {"name":"foobar","value":123,"map":{"a":true}}

/* INPUT = {
  "hashJsonProgram": "1078902799906427895065744095725393469743232200640180720201388375607563017615",
	"jsonProgram": [123, 34, 110, 97, 109, 101, 34, 58, 34, 102, 111, 111, 98, 97, 114, 34, 44, 34, 118, 97, 108, 117, 101, 34, 58, 49, 50, 51, 44, 34, 109, 97, 112, 34, 58, 123, 34, 97, 34, 58, 116, 114, 117, 101, 125, 125, 0, 0, 0, 0],
	"keys": [[[34, 109, 97, 112, 34, 0, 0, 0, 0, 0], [34, 97, 34, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]]],
	"values": [[116, 114, 117, 101, 0, 0, 0, 0, 0, 0]],
	"keysOffset": [[[29, 33], [36, 38], [0, 0]]],
	"valuesOffset": [[40, 43]],
  "pubKey":["0","1","1","1","0","1","0","1","0","1","1","0","1","0","1","0","1","0","0","0","1","1","1","1","0","0","1","0","0","0","0","1","1","1","1","0","1","1","1","0","0","0","1","0","1","1","0","0","1","1","0","0","1","0","0","0","0","0","1","0","0","1","1","0","1","1","0","0","1","0","0","1","0","0","0","0","0","1","1","0","0","1","1","0","1","0","1","0","0","1","1","0","0","0","0","0","0","0","1","0","0","1","0","0","1","0","0","1","0","1","0","0","1","0","1","0","1","0","0","0","0","0","1","0","0","1","1","0","0","1","1","1","1","0","0","1","1","1","0","0","1","0","1","1","1","1","0","1","0","1","0","1","1","0","1","1","1","0","1","1","1","0","0","0","0","1","1","1","0","0","0","1","1","0","0","1","1","1","0","1","1","0","0","1","1","0","1","0","1","1","1","0","0","0","1","0","0","0","0","0","1","1","0","0","1","1","0","1","1","0","0","1","0","0","0","1","0","0","0","1","0","0","1","1","0","1","0","0","0","1","1","0","0","1","0","0","1","0","1","0","1","0","0","0","1","0","0","1","0","1","0","1","0","1","0","1"],
  "R8":["1","1","1","0","1","0","1","1","1","1","1","0","1","0","1","1","1","1","1","1","1","0","0","0","0","0","1","0","0","0","1","1","0","1","1","1","1","1","0","0","1","1","0","1","0","1","1","1","0","1","0","0","1","0","1","0","0","0","1","1","0","1","1","1","1","1","0","0","0","0","1","1","0","0","0","1","1","0","1","1","0","1","0","1","1","0","1","1","1","1","0","0","0","1","0","1","1","0","1","1","1","0","1","0","1","1","0","1","1","0","0","0","1","1","0","0","0","1","1","0","0","1","1","0","0","0","0","1","0","1","0","1","0","0","1","1","1","0","1","0","1","0","0","1","0","0","0","0","1","0","0","1","1","0","0","1","1","1","0","1","0","1","0","0","1","0","1","1","0","0","0","1","1","0","1","0","1","1","0","0","0","1","1","0","0","0","0","1","1","0","1","1","0","0","0","0","1","1","0","1","1","0","0","1","0","0","0","0","0","1","1","1","0","0","1","1","1","1","1","1","0","1","0","0","1","1","1","0","1","0","1","1","0","1","0","0","1","1","0","0","0","0","1","0","0","1","1","1","1","1","0","0","0","0","0","1"],
  "S":["1","1","1","0","1","1","1","1","0","0","0","1","0","1","0","1","1","1","0","1","1","1","1","1","0","1","1","1","0","0","0","1","1","1","0","1","1","1","1","0","1","0","0","0","1","0","0","0","1","1","1","0","1","1","1","1","0","0","0","0","1","0","1","0","1","1","0","1","0","0","1","0","1","0","1","1","1","0","0","1","0","0","0","1","0","0","1","1","0","0","1","0","0","1","1","0","1","1","0","1","0","0","1","0","1","0","0","0","0","1","1","0","1","0","1","0","1","0","1","0","1","1","0","0","0","1","1","1","0","1","1","0","0","0","0","0","1","1","0","1","0","0","1","1","0","1","0","1","0","0","0","1","0","1","0","1","0","1","1","0","1","0","1","0","1","1","1","1","0","0","1","0","0","0","1","1","0","0","0","0","0","0","0","1","1","1","1","0","0","1","1","0","1","1","1","1","1","1","1","1","1","0","0","1","0","1","0","1","0","0","1","1","0","0","1","1","0","1","1","1","0","1","1","0","1","1","1","1","1","1","0","1","1","0","1","0","0","0","0","1","1","1","1","1","0","1","1","0","0","0","1","0","0","0","0","0"]
  } */