// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title AgentOre
/// @notice Experimental ERC-20 issuance weighted by self-reported AI token usage.
/// @dev Reported usage is not authenticated by an AI provider. Do not use with valuable assets.
contract AgentOre {
    struct Entry {
        address account;
        uint256 cumulativeWeight;
    }

    string public constant name = "Agent Ore";
    string public constant symbol = "AORE";
    uint8 public constant decimals = 18;
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant MAX_SUPPLY = 21_000_000 ether;
    uint256 public constant SYNTHETIC_BLOCKS_PER_EPOCH = 144;
    uint256 public constant HALVING_INTERVAL_BLOCKS = 210_000;
    uint256 public constant INITIAL_BLOCK_REWARD = 50 ether;

    uint256 public immutable genesisTime;
    uint256 public immutable epochDuration;
    uint256 public immutable finalizerBps;

    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    mapping(address => bool) public registered;
    mapping(address => uint256) public lastCumulativeTokens;
    mapping(uint256 => mapping(address => bool)) public submittedInEpoch;
    mapping(uint256 => uint256) public totalWeight;
    mapping(uint256 => bool) public finalized;
    mapping(uint256 => address) public winner;
    mapping(uint256 => uint256) public mintedReward;
    mapping(uint256 => Entry[]) private entries;

    error InvalidConfiguration();
    error ZeroAddress();
    error AlreadySubmitted(uint256 epoch, address account);
    error CounterDidNotIncrease(uint256 previous, uint256 supplied);
    error EpochStillOpen(uint256 epoch);
    error EpochAlreadyFinalized(uint256 epoch);
    error InsufficientBalance();
    error InsufficientAllowance();
    error EntryOutOfBounds();
    error MaxSupplyExceeded();

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event BaselineEstablished(
        address indexed account, uint256 indexed epoch, uint256 cumulativeTokens
    );
    event UsageSubmitted(
        address indexed account,
        uint256 indexed epoch,
        uint256 cumulativeTokens,
        uint256 deltaTokens,
        uint256 epochTotalWeight
    );
    event EpochFinalized(
        uint256 indexed epoch,
        address indexed winner,
        address indexed finalizer,
        uint256 winningPoint,
        uint256 winnerReward,
        uint256 finalizerReward
    );

    constructor(uint256 epochDuration_, uint256 finalizerBps_) {
        if (epochDuration_ == 0 || finalizerBps_ > BPS_DENOMINATOR) {
            revert InvalidConfiguration();
        }

        genesisTime = block.timestamp;
        epochDuration = epochDuration_;
        finalizerBps = finalizerBps_;
    }

    function currentEpoch() public view returns (uint256) {
        return (block.timestamp - genesisTime) / epochDuration;
    }

    function epochStart(uint256 epoch) external view returns (uint256) {
        return genesisTime + epoch * epochDuration;
    }

    function rewardForEpoch(uint256 epoch) public pure returns (uint256) {
        if (epoch > type(uint256).max / SYNTHETIC_BLOCKS_PER_EPOCH) return 0;

        uint256 syntheticBlock = epoch * SYNTHETIC_BLOCKS_PER_EPOCH;
        uint256 blocksRemaining = SYNTHETIC_BLOCKS_PER_EPOCH;
        uint256 reward;

        while (blocksRemaining != 0) {
            uint256 halvings = syntheticBlock / HALVING_INTERVAL_BLOCKS;
            if (halvings >= 256) break;

            uint256 blockReward = INITIAL_BLOCK_REWARD >> halvings;
            if (blockReward == 0) break;

            uint256 nextHalvingBlock = (halvings + 1) * HALVING_INTERVAL_BLOCKS;
            uint256 blocksInSegment = nextHalvingBlock - syntheticBlock;
            if (blocksInSegment > blocksRemaining) blocksInSegment = blocksRemaining;

            reward += blocksInSegment * blockReward;
            syntheticBlock += blocksInSegment;
            blocksRemaining -= blocksInSegment;
        }

        return reward;
    }

    /// @notice Establish a baseline or submit new cumulative usage for the current epoch.
    /// @dev The first call only establishes a baseline and produces no mining weight.
    function submit(uint256 cumulativeTokens) external {
        uint256 epoch = currentEpoch();
        if (submittedInEpoch[epoch][msg.sender]) {
            revert AlreadySubmitted(epoch, msg.sender);
        }

        if (!registered[msg.sender]) {
            registered[msg.sender] = true;
            submittedInEpoch[epoch][msg.sender] = true;
            lastCumulativeTokens[msg.sender] = cumulativeTokens;
            emit BaselineEstablished(msg.sender, epoch, cumulativeTokens);
            return;
        }

        uint256 previous = lastCumulativeTokens[msg.sender];
        if (cumulativeTokens <= previous) {
            revert CounterDidNotIncrease(previous, cumulativeTokens);
        }

        uint256 delta = cumulativeTokens - previous;
        uint256 newTotalWeight = totalWeight[epoch] + delta;

        submittedInEpoch[epoch][msg.sender] = true;
        lastCumulativeTokens[msg.sender] = cumulativeTokens;
        totalWeight[epoch] = newTotalWeight;
        entries[epoch].push(Entry({ account: msg.sender, cumulativeWeight: newTotalWeight }));

        emit UsageSubmitted(msg.sender, epoch, cumulativeTokens, delta, newTotalWeight);
    }

    /// @notice Settle a closed epoch. Any address may finalize.
    /// @dev The random source is biasable and is suitable only for a valueless prototype.
    function finalize(uint256 epoch) external returns (address selectedWinner) {
        if (epoch >= currentEpoch()) revert EpochStillOpen(epoch);
        if (finalized[epoch]) revert EpochAlreadyFinalized(epoch);

        finalized[epoch] = true;
        uint256 weight = totalWeight[epoch];

        if (weight == 0) {
            emit EpochFinalized(epoch, address(0), msg.sender, 0, 0, 0);
            return address(0);
        }

        uint256 randomValue = uint256(
            keccak256(
                abi.encode(
                    block.prevrandao,
                    blockhash(block.number - 1),
                    epoch,
                    weight,
                    address(this),
                    msg.sender
                )
            )
        );
        uint256 winningPoint = randomValue % weight;
        selectedWinner = _winnerAt(epoch, winningPoint);

        uint256 reward = rewardForEpoch(epoch);
        uint256 remainingSupply = MAX_SUPPLY - totalSupply;
        if (reward > remainingSupply) reward = remainingSupply;
        uint256 finalizerReward = reward * finalizerBps / BPS_DENOMINATOR;
        uint256 winnerReward = reward - finalizerReward;

        winner[epoch] = selectedWinner;
        mintedReward[epoch] = reward;

        _mint(selectedWinner, winnerReward);
        _mint(msg.sender, finalizerReward);

        emit EpochFinalized(
            epoch, selectedWinner, msg.sender, winningPoint, winnerReward, finalizerReward
        );
    }

    function entryCount(uint256 epoch) external view returns (uint256) {
        return entries[epoch].length;
    }

    function entryAt(uint256 epoch, uint256 index) external view returns (Entry memory) {
        if (index >= entries[epoch].length) revert EntryOutOfBounds();
        return entries[epoch][index];
    }

    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < value) revert InsufficientAllowance();
            unchecked {
                allowance[from][msg.sender] = allowed - value;
            }
            emit Approval(from, msg.sender, allowance[from][msg.sender]);
        }
        _transfer(from, to, value);
        return true;
    }

    function _winnerAt(uint256 epoch, uint256 point) private view returns (address) {
        Entry[] storage epochEntries = entries[epoch];
        uint256 low;
        uint256 high = epochEntries.length;

        while (low < high) {
            uint256 mid = (low + high) / 2;
            if (epochEntries[mid].cumulativeWeight > point) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        return epochEntries[low].account;
    }

    function _mint(address to, uint256 value) private {
        if (value == 0) return;
        if (value > MAX_SUPPLY - totalSupply) revert MaxSupplyExceeded();
        totalSupply += value;
        balanceOf[to] += value;
        emit Transfer(address(0), to, value);
    }

    function _transfer(address from, address to, uint256 value) private {
        if (to == address(0)) revert ZeroAddress();
        uint256 fromBalance = balanceOf[from];
        if (fromBalance < value) revert InsufficientBalance();
        unchecked {
            balanceOf[from] = fromBalance - value;
            balanceOf[to] += value;
        }
        emit Transfer(from, to, value);
    }
}
