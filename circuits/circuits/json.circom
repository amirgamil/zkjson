pragma circom 2.1.0;

include "../node_modules/circomlib/circuits/bitify.circom";
include "../node_modules/circomlib/circuits/comparators.circom";
include "../node_modules/circomlib/circuits/multiplexer.circom";

template ValueCompare(jsonLength, LARGE_CONSTANT) {
    signal input keyOffset[2];
    signal input JSON[jsonLength];
    signal input attribute[LARGE_CONSTANT];
    signal input on;

    signal inKey[LARGE_CONSTANT+1];
    inKey[0] <== 1;

    component equals[LARGE_CONSTANT];
    for (var i = 0; i < LARGE_CONSTANT; i++) {
        equals[i] = IsEqual();
        equals[i].in[0] <== i;
        equals[i].in[1] <== keyOffset[1] - keyOffset[0];
        inKey[i+1] <== inKey[i] - equals[i].out;
    }

    component shift = ShiftLeft(jsonLength, 1, jsonLength);

    shift.shift <== keyOffset[0];
    for (var i = 0; i < jsonLength; i++) {
        shift.in[i] <== JSON[i];
    }

    signal intermediates[LARGE_CONSTANT];
    for (var i = 0; i < LARGE_CONSTANT; i++) {
        intermediates[i] <== (shift.out[i] - attribute[i]) * inKey[i];
        0 === intermediates[i] * on;
    }
}

function log_ceil(n) {
   var n_temp = n;
   for (var i = 0; i < 254; i++) {
       if (n_temp == 0) {
          return i;
       }
       n_temp = n_temp \ 2;
   }
   return 254;
}

template ShiftLeft(nIn, minShift, maxShift) {
    signal input in[nIn];
    signal input shift;
    signal output out[nIn];

    var shiftBits = log_ceil(maxShift - minShift);

    component n2b = Num2Bits(shiftBits);
    signal shifts[shiftBits][nIn];
    
    if (minShift == maxShift) {
        n2b.in <== 0;
        for (var i = 0; i < nIn; i++) {
	        out[i] <== in[(i + minShift) % nIn];
	    }
    } else {
	    n2b.in <== shift - minShift;

        for (var idx = 0; idx < shiftBits; idx++) {
            if (idx == 0) {
                for (var j = 0; j < nIn; j++) {
                    var tempIdx = (j + minShift + (1 << idx)) % nIn;
                    var tempIdx2 = (j + minShift) % nIn;
                    shifts[0][j] <== n2b.out[idx] * (in[tempIdx] - in[tempIdx2]) + in[tempIdx2];
                }
            } else {
                for (var j = 0; j < nIn; j++) {
                    var prevIdx = idx - 1;
                    var tempIdx = (j + (1 << idx)) % nIn;
                    shifts[idx][j] <== n2b.out[idx] * (shifts[prevIdx][tempIdx] - shifts[prevIdx][j]) + shifts[prevIdx][j];
                }
            }
        }
        for (var i = 0; i < nIn; i++) {
            out[i] <== shifts[shiftBits - 1][i];
        }
    }
}

template StringKeyCompare(attrLength, jsonLength) {
    signal input keyOffset[2];
    signal input JSON[jsonLength];
    signal input attribute[attrLength];

    component shift = ShiftLeft(jsonLength, 1, jsonLength);

    shift.shift <== keyOffset[0];
    for (var i = 0; i < jsonLength; i++) {
        shift.in[i] <== JSON[i];
    }

    for (var i = 0; i < attrLength; i++) {
        shift.out[i] === attribute[i];
    }
}