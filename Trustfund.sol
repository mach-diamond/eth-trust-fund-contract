// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct Transaction {
    uint datetime;
    int amount;
    uint netBalance;
}

struct TrustFund {
    address beneficiary;
    uint lastPayout;
    uint fundAmount;
    uint payoutInterval;
    uint payoutAmount;
	uint originalPayoutAmount;
}

contract TrustFunds {
	address public owner;
    mapping(address => TrustFund) public trustFunds;
    event FundsAdded(uint256 amount, address sender);
    event WithdrawMade(uint256 amount, uint remainingBalance, address beneficiary);

    constructor() {
		owner = msg.sender;
    }

    modifier isOwner() {
        require(msg.sender == owner, "Not the Owner");
        _;
    }

	modifier trustFundExists(address _beneficiary) {
		TrustFund storage trustFund = trustFunds[_beneficiary];
		require(trustFund.beneficiary != address(0), "Trustfund with provided beneficiary does not exist");
		_;
	}

    function withdraw() external trustFundExists(msg.sender) {
		TrustFund storage trustFund = trustFunds[msg.sender];
        require(block.timestamp >= trustFund.lastPayout + trustFund.payoutInterval, "Payout interval not reached");
        require(trustFund.fundAmount >= trustFund.payoutAmount, "The contract does not have enough funds for payout");

        uint cyclesMissed = (block.timestamp - trustFund.lastPayout) / trustFund.payoutInterval;
        uint amount = cyclesMissed * trustFund.payoutAmount;

        // Update state before transferring Ether
        trustFund.fundAmount -= amount;
        trustFund.lastPayout = block.timestamp;

        // Transfer Ether
        payable(msg.sender).transfer(amount);

        emit WithdrawMade(amount, trustFund.fundAmount, msg.sender);
    }

    function deposit(address beneficiary) external payable trustFundExists(beneficiary) {
		TrustFund storage trustFund = trustFunds[beneficiary];
        require(msg.value > 0.01 ether, "Must add some amount of Ether, minimum deposit is 0.01 ether");
        trustFund.fundAmount += msg.value;
        emit FundsAdded(msg.value, msg.sender);
    }

	function createTrustFund(address beneficiary, uint payoutAmount, uint payoutInterval) public isOwner {
        require(trustFunds[beneficiary].beneficiary == address(0), "Trust fund already exists for beneficiary");
        trustFunds[beneficiary] = TrustFund(beneficiary, 0, 0, payoutInterval, payoutAmount, payoutAmount);
    }

	function updatePayAmount(address beneficiary, uint newAmount) public trustFundExists(beneficiary) {
		TrustFund storage trustFund = trustFunds[beneficiary];
		uint fivePercent =  trustFund.originalPayoutAmount / 20; // 5% of the current amount
        uint lowerBound = trustFund.originalPayoutAmount - fivePercent;
        uint upperBound = trustFund.originalPayoutAmount + fivePercent;

        require(newAmount >= lowerBound, "New amount is too low");
        require(newAmount <= upperBound, "New amount is too high");

        trustFund.payoutAmount = newAmount;
	}
}
