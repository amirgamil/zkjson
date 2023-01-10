pragma circom 2.0.8;

include "circomlib/comparators.circom";
include "./inRange.circom";

template getCharType() {
  signal input in; // ascii value
  signal output out[9]; // 

  component equals[6];
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
template JsonFull(jsonProgramSize, stackDepth) {
    // string of all the json
    signal input jsonProgram[jsonProgramSize];
    signal output out;

    // + 1 to allocate empty memory field
    signal jsonStack[jsonProgramSize + 1][stackDepth];

    signal states[jsonProgramSize+1][8];

    states[0][0] <== 1;
    for (var i = 1; i < 8; i ++) {
      states[0][i] <== 0;
    }
    
    // 
    component gt[jsonProgramSize][stackDepth];
    component eq[jsonProgramSize][stackDepth];

    component charTypes[jsonProgramSize];

    jsonStack[0][0] <== 1;
    for (var j = 1; j < stackDepth; j++) {
      jsonStack[0][j] <== 0;
    }

    // jsonProgram[0] === 123;
    // jsonProgram[jsonProgramSize-1] === 125;

    signal intermediates[jsonProgramSize][10];
    signal more_intermediates[jsonProgramSize][stackDepth][2];

    for (var i = 0; i < jsonProgramSize; i++) {
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

      jsonStack[i][0] <== jsonStack[i][1] * charTypes[i].out[1];
      jsonStack[i][stackDepth-1] <== jsonStack[i][stackDepth-1] * charTypes[i].out[0];
      for (var j = 1; j < stackDepth-1; j++) {
          eq[i][j] = IsEqual();
          eq[i][j].in[0] <== 1;
          eq[i][j].in[1] <== jsonStack[i][j];

          more_intermediates[i][j][0] <== jsonStack[i][j-1] * charTypes[i].out[0]; // stack++;
          more_intermediates[i][j][1] <== jsonStack[i][j+1] * charTypes[i].out[1]; // stack--;
          jsonStack[i+1][j] <== more_intermediates[i][j][0] + more_intermediates[i][j][1]; // stack++ or stack--;
      }
    }

    for (var i = 0; i < jsonProgramSize + 1; i++) {
      for (var j = 0; j < 9; j++) {
        log(states[i][j]);
      }
      log("----------");
    }

    out <== states[jsonProgramSize][4] * 1;
    // stackPtrIsEqual.out;
}

component main { public [ jsonProgram ] } = JsonFull(7, 4);

/* INPUT = {
    "jsonProgram": [123, 34, 97, 34, 58, 123, 125]
} */

// {"a":{}}
