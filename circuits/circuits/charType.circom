pragma circom 2.1.2;

include "../node_modules/circomlib/circuits/comparators.circom";
include "../node_modules/circomlib/circuits/gates.circom";

template Num2Bits2(n) {
    signal input in;
    signal output outs[n];
    signal output out;
    var lc1=0;

    var e2=1;
    for (var i = 0; i<n; i++) {
        outs[i] <-- (in >> i) & 1;
        outs[i] * (outs[i] -1 ) === 0;
        lc1 += outs[i] * e2;
        e2 = e2+e2;
    }

    component equals;
    equals = IsEqual();
    equals.in[0] <== lc1;
    equals.in[1] <== in;
    out <== equals.out;
}

template getCharType() {
    signal input in; // ascii value
    signal output out[18]; // 

    var sum = 0;
    var asciis[16] = [125, 123, 44, 91, 93, 58, 0, 34, 116, 114, 117, 101, 102, 97, 108, 115];
    var indices[16] = [0, 1, 2, 3, 4, 5, 9, 8, 10, 11, 12, 13, 14, 15, 16, 17];

    for (var i=0; i<16; i++) {
        out[indices[i]] <-- (in == asciis[i]) ? 1 : 0;
        out[indices[i]] * (in-asciis[i]) === 0;
        sum = sum + out[indices[i]];
    }

    0 === sum * (sum - 1);

    component left = Num2Bits2(4);
    component right = Num2Bits2(4);
    left.in <== in - 48;
    right.in <== 57 - in;

    out[6] <== left.out * right.out;
    // any character other than 0 or " is fine in a string
    out[7] <== 1 - out[8] - out[9];
}