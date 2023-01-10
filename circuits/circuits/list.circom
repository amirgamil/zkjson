pragma circom 2.1.0;

include "../node_modules/circomlib/circuits/comparators.circom";
include "../node_modules/circomlib/circuits/gates.circom";

template MultiOROld(n) {
    signal input in[n];
    signal output out;
    component or1;
    component or2;
    component ors[2];
    if (n==1) {
        out <== in[0];
    } else if (n==2) {
        or1 = OR();
        or1.a <== in[0];
        or1.b <== in[1];
        out <== or1.out;
    } else {
        or2 = OR();
        var n1 = n\2;
        var n2 = n-n\2;
        ors[0] = MultiOR(n1);
        ors[1] = MultiOR(n2);
        var i;
        for (i=0; i<n1; i++) ors[0].in[i] <== in[i];
        for (i=0; i<n2; i++) ors[1].in[i] <== in[n1+i];
        or2.a <== ors[0].out;
        or2.b <== ors[1].out;
        out <== or2.out;
    }
}

template MultiOR(n) {
    signal input in[n];
    signal output out;

    signal sums[n];
    sums[0] <== in[0];
    for (var i = 1; i < n; i++) {
        sums[i] <== sums[i-1] + in[i];
    }

    component is_zero = IsZero();
    is_zero.in <== sums[n-1];
    out <== 1 - is_zero.out;
}

template ListVerify(listLength) {
  signal input in[listLength];
  component eq[10][listLength];
  component lt[10][listLength];
  component and[17][listLength];
  component multi_or[5][listLength];
  signal states[listLength+1][6];

  signal output out;

  for (var i = 0; i < listLength; i++) {
    states[i][0] <== 1;
  }
  for (var i = 1; i < 6; i++) {
    states[0][i] <== 0;
  }

  for (var i = 0; i < listLength; i++) {
    lt[0][i] = LessThan(8);
    lt[0][i].in[0] <== 64;
    lt[0][i].in[1] <== in[i];
    lt[1][i] = LessThan(8);
    lt[1][i].in[0] <== in[i];
    lt[1][i].in[1] <== 91;
    and[0][i] = AND();
    and[0][i].a <== lt[0][i].out;
    and[0][i].b <== lt[1][i].out;
    lt[2][i] = LessThan(8);
    lt[2][i].in[0] <== 96;
    lt[2][i].in[1] <== in[i];
    lt[3][i] = LessThan(8);
    lt[3][i].in[0] <== in[i];
    lt[3][i].in[1] <== 123;
    and[1][i] = AND();
    and[1][i].a <== lt[2][i].out;
    and[1][i].b <== lt[3][i].out;
    lt[4][i] = LessThan(8);
    lt[4][i].in[0] <== 47;
    lt[4][i].in[1] <== in[i];
    lt[5][i] = LessThan(8);
    lt[5][i].in[0] <== in[i];
    lt[5][i].in[1] <== 58;
    and[2][i] = AND();
    and[2][i].a <== lt[4][i].out;
    and[2][i].b <== lt[5][i].out;
    eq[0][i] = IsEqual();
    eq[0][i].in[0] <== in[i];
    eq[0][i].in[1] <== 95;
    and[3][i] = AND();
    and[3][i].a <== states[i][1];
    multi_or[0][i] = MultiOR(4);
    multi_or[0][i].in[0] <== and[0][i].out;
    multi_or[0][i].in[1] <== and[1][i].out;
    multi_or[0][i].in[2] <== and[2][i].out;
    multi_or[0][i].in[3] <== eq[0][i].out;
    and[3][i].b <== multi_or[0][i].out;
    eq[1][i] = IsEqual();
    eq[1][i].in[0] <== in[i];
    eq[1][i].in[1] <== 34;
    and[4][i] = AND();
    and[4][i].a <== states[i][2];
    and[4][i].b <== eq[1][i].out;
    multi_or[1][i] = MultiOR(2);
    multi_or[1][i].in[0] <== and[3][i].out;
    multi_or[1][i].in[1] <== and[4][i].out;
    states[i+1][1] <== multi_or[1][i].out;
    eq[2][i] = IsEqual();
    eq[2][i].in[0] <== in[i];
    eq[2][i].in[1] <== 91;
    and[5][i] = AND();
    and[5][i].a <== states[i][0];
    and[5][i].b <== eq[2][i].out;
    eq[3][i] = IsEqual();
    eq[3][i].in[0] <== in[i];
    eq[3][i].in[1] <== 44;
    and[6][i] = AND();
    and[6][i].a <== states[i][2];
    and[6][i].b <== eq[3][i].out;
    eq[4][i] = IsEqual();
    eq[4][i].in[0] <== in[i];
    eq[4][i].in[1] <== 44;
    and[7][i] = AND();
    and[7][i].a <== states[i][3];
    and[7][i].b <== eq[4][i].out;
    eq[5][i] = IsEqual();
    eq[5][i].in[0] <== in[i];
    eq[5][i].in[1] <== 44;
    and[8][i] = AND();
    and[8][i].a <== states[i][4];
    and[8][i].b <== eq[5][i].out;
    multi_or[2][i] = MultiOR(4);
    multi_or[2][i].in[0] <== and[5][i].out;
    multi_or[2][i].in[1] <== and[6][i].out;
    multi_or[2][i].in[2] <== and[7][i].out;
    multi_or[2][i].in[3] <== and[8][i].out;
    states[i+1][2] <== multi_or[2][i].out;
    lt[6][i] = LessThan(8);
    lt[6][i].in[0] <== 47;
    lt[6][i].in[1] <== in[i];
    lt[7][i] = LessThan(8);
    lt[7][i].in[0] <== in[i];
    lt[7][i].in[1] <== 58;
    and[9][i] = AND();
    and[9][i].a <== lt[6][i].out;
    and[9][i].b <== lt[7][i].out;
    and[10][i] = AND();
    and[10][i].a <== states[i][2];
    and[10][i].b <== and[9][i].out;
    lt[8][i] = LessThan(8);
    lt[8][i].in[0] <== 47;
    lt[8][i].in[1] <== in[i];
    lt[9][i] = LessThan(8);
    lt[9][i].in[0] <== in[i];
    lt[9][i].in[1] <== 58;
    and[11][i] = AND();
    and[11][i].a <== lt[8][i].out;
    and[11][i].b <== lt[9][i].out;
    and[12][i] = AND();
    and[12][i].a <== states[i][3];
    and[12][i].b <== and[11][i].out;
    multi_or[3][i] = MultiOR(2);
    multi_or[3][i].in[0] <== and[10][i].out;
    multi_or[3][i].in[1] <== and[12][i].out;
    states[i+1][3] <== multi_or[3][i].out;
    eq[6][i] = IsEqual();
    eq[6][i].in[0] <== in[i];
    eq[6][i].in[1] <== 34;
    and[13][i] = AND();
    and[13][i].a <== states[i][1];
    and[13][i].b <== eq[6][i].out;
    states[i+1][4] <== and[13][i].out;
    eq[7][i] = IsEqual();
    eq[7][i].in[0] <== in[i];
    eq[7][i].in[1] <== 93;
    and[14][i] = AND();
    and[14][i].a <== states[i][2];
    and[14][i].b <== eq[7][i].out;
    eq[8][i] = IsEqual();
    eq[8][i].in[0] <== in[i];
    eq[8][i].in[1] <== 93;
    and[15][i] = AND();
    and[15][i].a <== states[i][3];
    and[15][i].b <== eq[8][i].out;
    eq[9][i] = IsEqual();
    eq[9][i].in[0] <== in[i];
    eq[9][i].in[1] <== 93;
    and[16][i] = AND();
    and[16][i].a <== states[i][4];
    and[16][i].b <== eq[9][i].out;
    multi_or[4][i] = MultiOR(3);
    multi_or[4][i].in[0] <== and[14][i].out;
    multi_or[4][i].in[1] <== and[15][i].out;
    multi_or[4][i].in[2] <== and[16][i].out;
    states[i+1][5] <== multi_or[4][i].out;
  }

  signal final_state_sum[listLength+1];
  final_state_sum[0] <== states[0][5];
  for (var i = 1; i <= listLength; i++) {
    final_state_sum[i] <== final_state_sum[i-1] + states[i][5];
  }
  out <== final_state_sum[listLength];
}

// component main { public [ in ] } = ListVerify(10);



/* INPUT = {
    "in": [97, 44, 98, 44, 99, 97, 44, 98, 44, 99]
} */
