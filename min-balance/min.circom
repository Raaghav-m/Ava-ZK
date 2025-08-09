pragma circom 2.0.0;
include "circomlib/circuits/bitify.circom";


template MinBalance(minBalance) {
    signal input balance;     // secret input (private)
    signal output isValid;    // output 1 if balance >= minBalance else 0


    signal diff;
    diff <== balance - minBalance;
    component bitsDecomp = Num2Bits(32);
    bitsDecomp.in <== diff;
    isValid <== 1;
}

component main = MinBalance(100);
