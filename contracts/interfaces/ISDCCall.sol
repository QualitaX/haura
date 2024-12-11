// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

interface ISDCCall {
    function inceptTrade(address _withParty, string memory _tradeData, int _position, int256 _paymentAmount, string memory _initialSettlementData, address _sdcContractAddress) external;
    function confirmTrade(address _withParty, string memory _tradeData, int _position, int256 _paymentAmount, string memory _initialSettlementData, address _sdcContractAddress) external;
    function performSettlement(int256 _settlementAmount, string memory _settlementData, address _sdcContractAddress) external;
    function requestTradeTermination(string memory _tradeId, int256 _terminationPayment, string memory _terminationTerms, address _sdcContractAddress) external;
    function confirmTradeTermination(string memory _tradeId, int256 _terminationPayment, string memory _terminationTerms, address _sdcContractAddress) external;
    function cancelTradeTermination(string memory _tradeId, int256 _terminationPayment, string memory _terminationTerms, address _sdcContractAddress) external;
    function requestReferenceRate(address _sdcContractAddress) external;
    function setURLs(string[] memory _urls, string memory _referenceRatePath, address _sdcContractAddress) external;
    function withdrawLink(address _sdcContractAddress) external;
    function getTradeState(address _sdcContractAddress) external view returns(TradeState);
    function getTradeID(address _sdcContractAddress) external view returns(string memory);
    function getInceptingTime(address _sdcContractAddress) external view returns(uint256);
    function getConfirmationTime(address _sdcContractAddress) external view returns(uint256);
    function getInitialMargin(address _sdcContractAddress) external view returns(uint256);
    function getInitialTerminationFee(address _sdcContractAddress) external view returns(uint256);
    function getMarginCall(address _account, address _sdcContractAddress) external view returns(uint256);
    function getMarginRequirement(address _account, address _sdcContractAddress) external view returns(Types.MarginRequirement memory);
    function getRateMultiplier(address _sdcContractAddress) external view returns(uint256);
    function getIRSReceipts(address _sdcContractAddress) external view returns(Types.IRSReceipt[] memory);
    function getURLs(address _sdcContractAddress) external view returns(string[] memory);
}