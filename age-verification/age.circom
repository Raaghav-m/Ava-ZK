pragma circom 2.0.0;

include "circomlib/circuits/comparators.circom";

template Over18Check(){
    signal input dob;            // e.g., days since epoch
    signal input currentdate;    // e.g., days since epoch
    signal output isOver18;      // final output: 1 if over 18

    signal mindob;
    mindob <== currentdate - 6570; // 18 years * 365 days

    component check = LessThan(32);
    check.in[0] <== dob;
    check.in[1] <== mindob;

    isOver18 <== check.out;  // 1 if dob < mindob
}

component main = Over18Check();