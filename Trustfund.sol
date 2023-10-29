// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct Transaction {
    uint datetime;
    int amount;
    uint netBalance;
}

contract TrustFund {
    // State Variables
    address public immutable owner;
    address public immutable beneficiary;
    
    Transaction[] public transactions;
    uint public fundAmount = 0; 

    uint public lastPayout;
    uint public payoutInterval; // in seconds
	uint private originalPayoutAmount;
    uint public payoutAmount; // in wei

    event FundsAdded(uint256 amount, address sender);
    event WithdrawMade(uint256 amount, uint remainingBalance);

    constructor(address _owner, address _beneficiary, uint _payoutAmount, uint _payoutInterval) payable {
        require(msg.value > 0.5 ether, "You must have a minimum initial deposit of 0.5 ether");
        fundAmount += msg.value;
        owner = _owner;
        beneficiary = _beneficiary;
        payoutInterval = _payoutInterval;
        payoutAmount = _payoutAmount;
		originalPayoutAmount = _payoutAmount;
		lastPayout = block.timestamp;

        newTransaction(int256(msg.value));
        emit FundsAdded(msg.value, msg.sender);
    }

    modifier isOwner() {
        require(msg.sender == owner, "Not the Owner");
        _;
    }

    modifier isBeneficiary() {
        require(msg.sender == beneficiary, "Not the Beneficiary");
        _;
    }

    function withdraw() external isBeneficiary() {
        require(block.timestamp >= lastPayout + payoutInterval, "Payout interval not reached");
        require(fundAmount >= payoutAmount, "The contract does not have enough funds for payout");

        uint cyclesMissed = (block.timestamp - lastPayout) / payoutInterval;
        uint amount = cyclesMissed * payoutAmount;

        // Update state before transferring Ether
        fundAmount -= amount;
        lastPayout = block.timestamp;
        newTransaction(int256(amount) * - 1);

        // Transfer Ether
        payable(beneficiary).transfer(amount);

        emit WithdrawMade(amount, fundAmount);
    }

    function deposit() external payable {
        require(msg.value > 0, "Must add some amount of Ether");
        fundAmount += msg.value;
        emit FundsAdded(msg.value, msg.sender);
        newTransaction(int256(msg.value));
    }

	function updatePayAmount(uint newAmount) public {
		uint fivePercent =  originalPayoutAmount / 20; // 5% of the current amount
        uint lowerBound = originalPayoutAmount - fivePercent;
        uint upperBound = originalPayoutAmount + fivePercent;

        require(newAmount >= lowerBound, "New amount is too low");
        require(newAmount <= upperBound, "New amount is too high");

        payoutAmount = newAmount;
	}

    function newTransaction(int256 amount) internal {
        Transaction memory newDeposit = Transaction(block.timestamp, amount, fundAmount);
        transactions.push(newDeposit);
    }
}
