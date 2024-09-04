// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Chainlink, ChainlinkClient} from "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "../interfaces/IERC7586.sol";
import "./IRSToken.sol";
import "../Types.sol";

abstract contract ERC7586 is IERC7586, IRSToken, ChainlinkClient {
    using Chainlink for Chainlink.Request;

    int256 internal referenceRate;
    int256 internal lockedReferenceRate;
    uint256 internal netSettlementAmount;
    uint8 internal transferMode;  // 0 -> transfer from payer account (transferFrom), 1 -> transfer from the contract balance (transfer)
    uint8 internal swapCount;

    address internal receiverParty;
    address internal payerParty;

    AggregatorV3Interface internal ETHStakingFeed;
    bytes32 private jobId;
    uint256 private fee;

    event RequestReferenceRate(bytes32 indexed requestId, int256 referenceRate);

    error invalidTransferMode(uint8 _transferMode);

    constructor(
        string memory _irsTokenName,
        string memory _irsTokenSymbol,
        Types.IRS memory _irs,
        address _linkToken,
        address _chainlinkOracle,
        bytes32 _jobId
    ) IRSToken(_irsTokenName, _irsTokenSymbol) {
        irs = _irs;
        ETHStakingFeed = AggregatorV3Interface(_irs.oracleContractForBenchmark);
        _setChainlinkToken(_linkToken);
        _setChainlinkOracle(_chainlinkOracle);
        jobId = _jobId;
        fee = (1 * LINK_DIVISIBILITY) / 10;  // 0,1 * 10**18 (Varies by network and job)

        // one token minted for each settlement cycle per counterparty
        uint256 balance = uint256(_irs.settlementDates.length) * 1 ether;
        _maxSupply = 2 * balance;

        mint(_irs.fixedRatePayer, balance);
        mint(_irs.floatingRatePayer, balance);
    }

    function fixedRatePayer() external view returns(address) {
        return irs.fixedRatePayer;
    }

    function floatingRatePayer() external view returns(address) {
        return irs.floatingRatePayer;
    }

    function ratesDecimals() external view returns(uint8) {
        return irs.ratesDecimals;
    }

    function swapRate() external view returns(int256) {
        return irs.swapRate;
    }

    function spread() external view returns(int256) {
        return irs.spread;
    }

    function dayCountBasis() external view returns(uint8) {
        return irs.dayCountBasis;
    }

    function settlementCurrency() external view returns(address) {
        return irs.settlementCurrency;
    }

    function notionalAmount() external view returns(uint256) {
        return irs.notionalAmount;
    }

    function settlementFrequency() external view returns(uint256) {
        return irs.settlementFrequency;
    }

    function settlementDates() external view returns(uint256[] memory) {
        return irs.settlementDates;
    }

    function startingDate() external view returns(uint256) {
        return irs.startingDate;
    }

    function maturityDate() external view returns(uint256) {
        return irs.maturityDate;
    }

    function oracleContractForBenchmark() external view returns(address) {
        return irs.oracleContractForBenchmark;
    }

    function benchmark() public view returns(int256) {
        return referenceRate;
    }

    /**
    * @notice make a API call to get the reference rate
    * @param _URL the URL to make the API call from
    * @param _path the path to the reference rate in the json response
    * @param _multiplier the multiplier. => referenceRate is mutiplied ny this number
    */
    function requestReferenceRate(
        string memory _URL,
        string memory _path,
        uint256 _multiplier
    ) public returns(bytes32 requestId) {
        Chainlink.Request memory req = _buildChainlinkRequest(
            jobId,
            address(this),
            this.fulfill.selector
        );

        req._add("get", _URL);
        req._add("path", _path);
        req._addInt("times", int256(_multiplier));

        // send the request
        return _sendChainlinkRequest(req, fee);
    }

    function fulfill(
        bytes32 _requestId,
        int256 _referenceRate
    ) public recordChainlinkFulfillment(_requestId) {
        emit RequestReferenceRate(_requestId, _referenceRate);

        referenceRate = _referenceRate;
    }


    //function benchmark() public view returns(int256) {
        //(
        //    /* uint80 roundID */,
        //    int stakingRate,
        //    /*uint startedAt*/,
        //    /*uint timeStamp*/,
        //    /*uint80 answeredInRound*/
        //) = ETHStakingFeed.latestRoundData();

        //return stakingRate;
    //}

    /**
    * @notice Transfer the net settlement amount to the receiver account.
    *         if `transferMode = 0` (enough balance in the payer account), transfer from the payer balance
    *         if `transferMode = 1` (not enough balance in the payer account), transfer from the payer margin buffer
    */
    function swap() public returns(bool) {
        burn(irs.fixedRatePayer, 1 ether);
        burn(irs.floatingRatePayer, 1 ether);

        uint256 settlementAmount = netSettlementAmount * 1 ether / 10_000;

        if (transferMode == 0) {
            IERC20(irs.settlementCurrency).transferFrom(payerParty, receiverParty, settlementAmount);
        } else if (transferMode == 1) {
            IERC20(irs.settlementCurrency).transfer(receiverParty, settlementAmount);
        } else {
            revert invalidTransferMode(transferMode);
        }

        emit Swap(receiverParty, settlementAmount);

        // Prevents the transfer of funds from the outside of ERC6123 contrat
        // This is possible because the receipient of the transferFrom function in ERC20 must not be the zero address
        receiverParty = address(0);

        return true;
    }

    function terminateSwap() external {

    }

    function getSwapCount() external view returns(uint8) {
        return swapCount;
    }

    /**
     * @notice Allow withdraw of Link tokens from the contract
     * !!!!!   SECURE THIS FUNCTION FROM BEING CALLED BY NOT ALLOWED USERS !!!!!
     */
    function withdrawLink() public {
        LinkTokenInterface link = LinkTokenInterface(_chainlinkTokenAddress());
        require(
            link.transfer(msg.sender, link.balanceOf(address(this))),
            "Unable to transfer"
        );
    }
}