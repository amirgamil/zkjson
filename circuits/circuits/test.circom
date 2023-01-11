template Example () {
    signal input a;
    signal input b;
    signal output c;
    
    var unused = 4;
    c <== a * b;
    assert(a > 2);
    
}

component main { public [ a ] } = Example();