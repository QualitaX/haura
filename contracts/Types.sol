// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;
abstract contract Types {
    struct IRS {
        address fixedRatePayer;
        address floatingRatePayer;
        address oracleContractForBenchmark;
        address settlementCurrency;
        uint8 ratesDecimals;
        uint8 dayCountBasis;
        int256 swapRate;
        int256 spread;
        uint256 notionalAmount;
        uint256 settlementFrequency;
        uint256 startingDate;
        uint256 maturityDate;
        uint256[] settlementDates;
    }

    struct MarginRequirement {
        uint256 marginBuffer;
        uint256 terminationFee;
    }
    
    struct IRSReceipt {
        address from;
        address to;
        uint256 netAmount;
        uint256 timestamp;
        uint256 fixedRatePayment;
        uint256 floatingRatePayment;
    }
}