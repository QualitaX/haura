// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/Strings.sol";

import "./interfaces/IERC6123.sol";
import "./ERC6123Storage.sol";
import "./assets/ERC7586.sol";
import "./Types.sol";

contract ERC6123 is IERC6123, ERC6123Storage, ERC7586 {
    using Chainlink for Chainlink.Request;

    event referenceRateFetched();

    modifier onlyCounterparty() {
        require(
            msg.sender == irs.fixedRatePayer || msg.sender == irs.floatingRatePayer,
            "You are not a counterparty."
        );
        _;
    }

    /**
    * _irsTokenName: "QualitaX Token"
    * _irsTokenSymbol: "QTX"
    * _irs: ["0xA2003BF3fEbB0E8DcdEA3c75F1699b5c443Cc7cc", "0x2aB0021165ed140EC25Bc320956963CA2d3dbca0", "0x6090149792dAAeE9D1D568c9f9a6F6B46AA29eFD", "0xeb0dF3662b780FC01DB1377393Ee3CD4692e19ad", 1, 0, 572, 0, 1000000, 360, 1728005308, 1728008908, [1728006328, 1728006928, 1728003928, 1728004528]]
    * _linkToken: "0x779877A7B0D9E8603169DdbD7836e478b4624789"
    * _chainlinkOracle: "0x6090149792dAAeE9D1D568c9f9a6F6B46AA29eFD" (Chainlink DevRel)
    * jobId = "fcf4140d696d44b687012232948bdd5d";
    * _initialMarginBuffer: 1000000
    * _initialTerminationFee: 500000
    * _rateMultiplier: 1
    * setURLs: ["https://x8ki-letl-twmt.n7.xano.io/api:aBashLUq/RetrieveSTKR?date=20210930&STKR=1", "https://x8ki-letl-twmt.n7.xano.io/api:aBashLUq/RetrieveSTKR?date=20211001&STKR=2", "https://x8ki-letl-twmt.n7.xano.io/api:aBashLUq/RetrieveSTKR?date=20211002&STKR=3", "https://x8ki-letl-twmt.n7.xano.io/api:aBashLUq/RetrieveSTKR?date=20211003&STKR=4"]
    * path: "0,STKR_in_pbs"
    */
    constructor (
        string memory _irsTokenName,
        string memory _irsTokenSymbol,
        Types.IRS memory _irs,
        address _linkToken,
        address _chainlinkOracle,
        string memory _jobId,
        uint256 _initialMarginBuffer,
        uint256 _initialTerminationFee,
        uint256 _rateMultiplier,
        uint256 _networkID
    ) ERC7586(_irsTokenName, _irsTokenSymbol, _irs, _linkToken, _chainlinkOracle) {
        initialMarginBuffer = _initialMarginBuffer;
        initialTerminationFee = _initialTerminationFee;
        confirmationTime = 1 hours;
        rateMultiplier = _rateMultiplier;
        networkID = _networkID;

        jobId = bytes32(abi.encodePacked(_jobId));
        fee = (1 * LINK_DIVISIBILITY) / 10;  // 0,1 * 10**18 (Varies by network and job)
    }

    function inceptTrade(
        address _withParty,
        string memory _tradeData,
        int _position,
        int256 _paymentAmount,
        string memory _initialSettlementData
    ) external override onlyCounterparty onlyWhenTradeInactive returns (string memory) {
        address inceptor = msg.sender;

        if(inceptor == _withParty)
            revert cannotInceptWithYourself(msg.sender, _withParty);
        require(
            _withParty == irs.fixedRatePayer || _withParty == irs.floatingRatePayer,
            "counterparty must be payer or receiver"
        );
        require(_position == 1 || _position == -1, "invalid position");

        if(_position == 1) {
            irs.fixedRatePayer = msg.sender;
            irs.floatingRatePayer = _withParty;
        } else {
            irs.floatingRatePayer = msg.sender;
            irs.fixedRatePayer = _withParty;
        }

        tradeState = TradeState.Incepted;

        uint256 dataHash = uint256(keccak256(
            abi.encode(
                msg.sender,
                _withParty,
                _tradeData,
                _position,
                _paymentAmount,
                _initialSettlementData
            )
        ));

        pendingRequests[dataHash] = msg.sender;
        tradeID = Strings.toString(dataHash);
        tradeData = _tradeData;
        inceptingTime = block.timestamp;

        emit TradeIncepted(
            msg.sender,
            _withParty,
            tradeID,
            _tradeData,
            _position,
            _paymentAmount,
            _initialSettlementData
        );

        marginRequirements[msg.sender] = Types.MarginRequirement({
            marginBuffer: initialMarginBuffer,
            terminationFee: initialTerminationFee
        });

        //The initial margin and the termination fee must be deposited into the contract
        uint256 marginAndFee = initialMarginBuffer + initialTerminationFee;

        require(
            IERC20(irs.settlementCurrency).transferFrom(msg.sender, address(this), marginAndFee * 1 ether),
            "Failed to transfer the initial margin + the termination fee"
        );

        return tradeID;
    }

    
    function confirmTrade(
        address _withParty,
        string memory _tradeData,
        int _position,
        int256 _paymentAmount,
        string memory _initialSettlementData
    ) external override onlyWhenTradeIncepted onlyWithinConfirmationTime {
        address inceptingParty = otherParty();

        uint256 confirmationHash = uint256(keccak256(
            abi.encode(
                _withParty,
                msg.sender,
                _tradeData,
                -_position,
                -_paymentAmount,
                _initialSettlementData
            )
        ));

        if(pendingRequests[confirmationHash] != inceptingParty)
            revert inconsistentTradeDataOrWrongAddress(inceptingParty, confirmationHash);

        delete pendingRequests[confirmationHash];
        tradeState = TradeState.Confirmed;

        emit TradeConfirmed(msg.sender, tradeID);

        marginRequirements[msg.sender] = Types.MarginRequirement({
            marginBuffer: initialMarginBuffer,
            terminationFee: initialTerminationFee
        });

        //The initial margin and the termination fee must be deposited into the contract
        uint256 marginAndFee = initialMarginBuffer + initialTerminationFee;

        require(
            IERC20(irs.settlementCurrency).transferFrom(msg.sender, address(this), marginAndFee * 1 ether),
            "Failed to transfer the initial margin + the termination fee"
        );
    }

    function cancelTrade(
        address _withParty,
        string memory _tradeData,
        int _position,
        int256 _paymentAmount,
        string memory _initialSettlementData
    ) external override onlyWhenTradeIncepted {
        address inceptingParty = msg.sender;

        uint256 confirmationHash = uint256(keccak256(
            abi.encode(
                msg.sender,
                _withParty,
                _tradeData,
                _position,
                _paymentAmount,
                _initialSettlementData
            )
        ));

        if(pendingRequests[confirmationHash] != inceptingParty)
            revert inconsistentTradeDataOrWrongAddress(inceptingParty, confirmationHash);

        delete pendingRequests[confirmationHash];
        tradeState = TradeState.Inactive;

        emit TradeCanceled(msg.sender, tradeID);
    }

    /**
    * @notice We don't implement the `initiateSettlement` function since this is done automatically
    */
    function initiateSettlement() external view override onlyCounterparty onlyWhenTradeConfirmed {
        revert obseleteFunction();
    }
    
    /**
    * @notice In case of Chainlink ETH Staking Rate, the rateMultiplier = 3. And the result MUST be devided by 10^7
    *         We assume rates are input in basis point
    */
    function performSettlement(
        int256 _settlementAmount,
        string memory _settlementData
    ) public override onlyWhenConfirmedOrSettled {
        uint8 _swapCount = swapCount;
        swapCount = _swapCount + 1;

        if(swapCount < irs.settlementDates.length) {
            tradeState = TradeState.Settled;
        } else if (swapCount == irs.settlementDates.length) {
            tradeState = TradeState.Matured;
        } else {
            revert allSettlementsDone();
        }

        _checkBalanceAndSwap(payerParty, uint256(_settlementAmount));

        emit SettlementEvaluated(msg.sender, _settlementAmount, _settlementData);
    }

    /**
    * @notice We don't implement the `afterTransfer` function since the transfer of the contract
    *         net present value is transferred in the `performSettlement function`.
    */
    function afterTransfer(bool /**success*/, string memory /*transactionData*/) external pure override {
        revert obseleteFunction();
    }

    /**-> NOT CLEAR: Why requesting trade termination after the trade has been settled ? */
    function requestTradeTermination(
        string memory _tradeId,
        int256 _terminationPayment,
        string memory _terminationTerms
    ) external override onlyCounterparty onlyWhenSettled {
        if(
            keccak256(abi.encodePacked(_tradeId)) != keccak256(abi.encodePacked(tradeID))
        ) revert invalidTradeID(_tradeId);

        uint256 terminationHash = uint256(keccak256(
            abi.encode(
                _tradeId,
                "terminate",
                _terminationPayment,
                _terminationTerms
            )
        ));

        pendingRequests[terminationHash] = msg.sender;

        emit TradeTerminationRequest(msg.sender, _tradeId, _terminationPayment, _terminationTerms);
    }

    function confirmTradeTermination(
        string memory _tradeId,
        int256 _terminationPayment,
        string memory _terminationTerms
    ) external onlyCounterparty onlyWhenSettled {
        address pendingRequestParty = otherParty();

        uint256 confirmationhash = uint256(keccak256(
            abi.encode(
                _tradeId,
                "terminate",
                _terminationPayment,
                _terminationTerms
            )
        ));

        if(pendingRequests[confirmationhash] != pendingRequestParty)
            revert inconsistentTradeDataOrWrongAddress(pendingRequestParty, confirmationhash);

        delete pendingRequests[confirmationhash];

        address terminationPayer = otherParty();
        terminationReceiver = msg.sender;
        uint256 buffer = marginRequirements[terminationReceiver].marginBuffer + marginRequirements[terminationPayer].marginBuffer;
        uint256 fees = marginRequirements[terminationReceiver].terminationFee + marginRequirements[terminationPayer].terminationFee;
        terminationAmount = buffer + fees;

        _updateMargin(terminationPayer, terminationReceiver);

        terminateSwap();

        tradeState = TradeState.Terminated;
    }

    function cancelTradeTermination(
        string memory _tradeId,
        int256 _terminationPayment,
        string memory _terminationTerms
    ) external onlyWhenSettled {
        address pendingRequestParty = msg.sender;

        uint256 confirmationHash = uint256(keccak256(
            abi.encode(
                _tradeId,
                "terminate",
                _terminationPayment,
                _terminationTerms
            )
        ));

        if(pendingRequests[confirmationHash] != pendingRequestParty)
            revert inconsistentTradeDataOrWrongAddress(pendingRequestParty, confirmationHash);

        delete pendingRequests[confirmationHash];

        emit TradeTerminationCanceled(msg.sender, _tradeId, _terminationTerms);
    }

    /**--------------------------------- Chainlink Automation --------------------------------*/
    /**
    * @notice make an API call to fetch the reference rate
    */
    function requestReferenceRate() public returns(bytes32 requestId) {
        Chainlink.Request memory req = _buildChainlinkRequest(
            jobId,
            address(this),
            this.fulfill.selector
        );

        req._add("get", referenceRateURLs[numberOfSettlement]);
        req._add("path", referenceRatePath);
        req._addInt("times", 1);

        uint256 nbOfSettlement = numberOfSettlement;
        numberOfSettlement = nbOfSettlement + 1;

        // send the request
        return _sendChainlinkRequest(req, fee);
    }

    function fulfill(
        bytes32 _requestId,
        int256 _referenceRate
    ) public recordChainlinkFulfillment(_requestId) {
        referenceRate = _referenceRate;

        emit referenceRateFetched();
    }

    function checkLog(
        Log calldata,
        bytes memory
    ) external view returns(bool upkeepNeeded, bytes memory performData) {
        upkeepNeeded = true;

        address payer;
        address receiver;
        uint256 netSettlementAmount;
        uint8 burnIRSTokens;

        int256 fixedRate = irs.swapRate;
        int256 floatingRate = referenceRate + irs.spread;

        uint256 fixedPayment = irs.notionalAmount * uint256(fixedRate) * 1 ether / (360 * 10_000);
        uint256 floatingPayment = irs.notionalAmount * uint256(floatingRate) * 1 ether / (360 * 10_000);

        if(fixedRate == floatingRate) {
            burnIRSTokens = 1;
        } else if(fixedRate > floatingRate) {
            receiver = irs.floatingRatePayer;
            payer = irs.fixedRatePayer;
            netSettlementAmount = fixedPayment - floatingPayment;
        } else {
            receiver = irs.fixedRatePayer;
            payer = irs.floatingRatePayer;
            netSettlementAmount = floatingPayment - fixedPayment;
        }

        performData = abi.encode(payer, receiver, int256(netSettlementAmount), fixedPayment, floatingPayment, burnIRSTokens);
    }

    function performUpkeep(bytes calldata performData) external override {
        (address payer, address receiver, int256 netSettlementAmount, uint256 fixedPayment, uint256 floatingPayment, uint8 burnIRSTokens) = abi.decode(
            performData, (address, address, int256, uint256, uint256, uint8)
        );

        payerParty = payer;
        receiverParty = receiver;
        fixedRatePayment = fixedPayment;
        floatingRatePayment = floatingPayment;
        settlementAmount = uint256(netSettlementAmount);

        performSettlement(netSettlementAmount, "");

        if(burnIRSTokens == 1) {
            burn(payer, 1 ether);
            burn(receiver, 1 ether);

            burnIRSTokens = 0;
        }
    }

    /** TO BE REMOVED: This function MUST be removed in production */
    function setURLs(string[] memory _urls, string memory _referenceRatePath) external onlyCounterparty {
        referenceRateURLs = _urls;
        referenceRatePath = _referenceRatePath;
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

    /**----------------------------- Transacctional functions --------------------------------*/
    /**
    * @notice Make a CALL to ERC-7586 swap function. Check that the payer has enough initial
    *         margin to make the transfer in case of insufficient balance during settlement
    * @param _payer The swap payer account address
    * @param _settlementAmount The net settlement amount to be transferred (in ether unit)
    */
    function _checkBalanceAndSwap(address _payer, uint256 _settlementAmount) private {
         uint256 balance = IERC20(irs.settlementCurrency).balanceOf(_payer);

         if (balance < _settlementAmount) {
            uint256 buffer = marginRequirements[_payer].marginBuffer;

            if(buffer < _settlementAmount) {
                revert notEnoughMarginBuffer(_settlementAmount, buffer);
            } else {
                marginRequirements[_payer].marginBuffer = buffer - _settlementAmount;
                marginCalls[_payer] = _settlementAmount;
                transferMode = 1;
                _updateIRSReceipt(_settlementAmount);
                swap();
                transferMode = 0;
            }
         } else {
            _updateIRSReceipt(_settlementAmount);
            swap();
         }
    }

    /**---------------------- Internal Private and other view functions ----------------------*/
    function _updateIRSReceipt(uint256 _settlementAmount) private {
        irsReceipts.push(
            Types.IRSReceipt({
                from: payerParty,
                to: receiverParty,
                netAmount: _settlementAmount,
                timestamp: block.timestamp,
                fixedRatePayment: fixedRatePayment,
                floatingRatePayment: floatingRatePayment,
                networkID: networkID
            })
        );
    }

    function _updateMargin(address _payer, address _receiver) private {
        marginRequirements[_payer].marginBuffer = 0;
        marginRequirements[_payer].terminationFee = 0;
        marginRequirements[_receiver].marginBuffer = 0;
        marginRequirements[_receiver].terminationFee = 0;
    }

    function getTradeState() external view returns(TradeState) {
        return tradeState;
    }

    function getTradeID() external view returns(string memory) {
        return tradeID;
    }

    function getInceptingTime() external view returns(uint256) {
        return inceptingTime;
    }

    function getConfirmationTime() external view returns(uint256) {
        return confirmationTime;
    }

    function getInitialMargin() external view returns(uint256) {
        return initialMarginBuffer;
    }

    function getInitialTerminationFee() external view returns(uint256) {
        return initialTerminationFee;
    }

    function getMarginCall(address _account) external view returns(uint256) {
        return marginCalls[_account];
    }

    function getMarginRequirement(address _account) external view returns(Types.MarginRequirement memory) {
        return marginRequirements[_account];
    }

    function getRateMultiplier() external view returns(uint256) {
        return rateMultiplier;
    }

    function otherParty() internal view returns(address) {
        return msg.sender == irs.fixedRatePayer ? irs.floatingRatePayer : irs.fixedRatePayer;
    }

    function otherParty(address _account) internal view returns(address) {
        return _account == irs.fixedRatePayer ? irs.floatingRatePayer : irs.fixedRatePayer;
    }

    function getIRSReceipts() external view returns(Types.IRSReceipt[] memory) {
        return irsReceipts;
    }

    function getURLs() external view returns(string[] memory) {
        return referenceRateURLs;
    }
}