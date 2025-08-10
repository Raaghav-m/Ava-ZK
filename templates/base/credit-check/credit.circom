pragma circom 2.0.0;

// Import Num2Bits from circomlib (make sure circomlib is installed)
include "circomlib/circuits/bitify.circom";

template MinCheck(minValue) {
    signal input in;
    signal output valid;

    signal diff;
    diff <== in - minValue;

    // Enforce diff >= 0 by bit decomposition
    component bitsDecomp = Num2Bits(32);
    bitsDecomp.in <== diff;

    valid <== 1;  // Just output 1 if constraints hold
}

template CreditAndBalanceCheck(minBalance, minCredit) {
    signal input balance;
    signal input creditScore;
    signal output isValid;

    component balCheck = MinCheck(minBalance);
    component creditCheck = MinCheck(minCredit);

    balCheck.in <== balance;
    creditCheck.in <== creditScore;

    // Both must be valid
    isValid <== balCheck.valid * creditCheck.valid;
}

component main = CreditAndBalanceCheck(100, 650);
