// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import {ILpETH, IERC20} from "./ILpETH.sol";
import {ILpETHVault} from "./ILpETHVault.sol";

/**
 * @title   PrelaunchPoints
 * @author  Loop
 * @notice  Staking points contract for the prelaunch of Loop Protocol.
 */
contract PrelaunchPoints {
    using Math for uint256;
    using SafeERC20 for IERC20;
    using SafeERC20 for ILpETH;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    ILpETH public lpETH;
    ILpETHVault public lpETHVault;

    address public owner;

    uint256 public totalSupply;
    uint256 public totalLpETH;

    uint32 public loopActivation;
    uint32 public startClaimDate;
    uint32 public immutable TIMELOCK;

    mapping(address => uint256) public balances;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Staked(address indexed user, uint256 amount, bytes32 indexed referral);
    event StakedVault(address indexed user, uint256 amount);
    event Converted(uint256 amountETH, uint256 amountlpETH);
    event Withdrawn(address indexed user, uint256 amount);
    event Claimed(address indexed user, uint256 reward);
    event Recovered(address token, uint256 amount);
    event OwnerUpdated(address newOwner);
    event LoopAddressesUpdated(address loopAddress, address vaultAddress);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error NothingToClaim();
    error CannotStakeZero();
    error CannotWithdrawZero();
    error FailedToSendEther();
    error LoopNotActivated();
    error NotValidToken();
    error NotAuthorized();
    error CurrentlyNotPossible();
    error NoLongerPossible();

    /*//////////////////////////////////////////////////////////////
                             INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    constructor() {
        owner = msg.sender;
        loopActivation = uint32(block.timestamp + 120 days);
        startClaimDate = 4294967295; // Max uint32 ~ year 2107
        TIMELOCK = 7 days;
    }

    /*//////////////////////////////////////////////////////////////
                            STAKE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Stakes ETH
     * @param _referral info of the referral. This value will be processed in the backend.
     */
    function stake(bytes32 _referral) public payable {
        _processStake(msg.value, msg.sender, _referral);
    }

    /**
     * @notice Stakes ETH for a given address
     * @param _referral info of the referral. This value will be processed in the backend.
     */
    function stakeFor(address _for, bytes32 _referral) external payable {
        _processStake(msg.value, _for, _referral);
    }

    /**
     * @dev Generic internal staking function that updates rewards based on
     *      previous balances, then update balances
     * @param _amount    Units to add to the users balance
     * @param _receiver  Address of user who will receive the stake
     * @param _referral  Address of the referral user
     */
    function _processStake(uint256 _amount, address _receiver, bytes32 _referral)
        internal
        onlyBeforeDate(loopActivation)
    {
        if (_amount == 0) {
            revert CannotStakeZero();
        }

        // update storage variables
        totalSupply = totalSupply + _amount;
        balances[_receiver] = balances[_receiver] + _amount;

        emit Staked(_receiver, _amount, _referral);
    }

    /*//////////////////////////////////////////////////////////////
                        CLAIM AND WITHDRAW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Called by a staker to get their vested lpETH
     */
    function claim() external onlyAfterDate(startClaimDate) {
        _claim(msg.sender);
    }

    /**
     * @dev Called by a staker to get their vested lpETH staked again in a
     *      Loop vault for extra rewards
     */
    function claimAndStake() external onlyAfterDate(startClaimDate) {
        uint256 claimedAmount = _claim(address(this));
        lpETH.approve(address(lpETHVault), claimedAmount);
        lpETHVault.stake(claimedAmount, msg.sender);

        emit StakedVault(msg.sender, claimedAmount);
    }

    function _claim(address _receiver) internal returns (uint256 claimedAmount) {
        uint256 userStake = balances[msg.sender];
        if (userStake == 0) {
            revert NothingToClaim();
        }

        claimedAmount = userStake.mulDiv(totalLpETH, totalSupply);
        balances[msg.sender] = 0;
        lpETH.safeTransfer(_receiver, claimedAmount);

        emit Claimed(msg.sender, claimedAmount);
    }

    /**
     * @dev Called by a staker to withdraw all their ETH
     * Note Can only be called after the loop address is set and before claiming lpETH,
     * i.e. for at least TIMELOCK
     */
    function withdraw() external onlyAfterDate(loopActivation) onlyBeforeDate(startClaimDate) {
        uint256 userStake = balances[msg.sender];
        if (userStake == 0) {
            revert CannotWithdrawZero();
        }

        totalSupply = totalSupply - userStake;
        balances[msg.sender] = 0;

        (bool sent,) = msg.sender.call{value: userStake}("");
        if (!sent) {
            revert FailedToSendEther();
        }

        emit Withdrawn(msg.sender, userStake);
    }

    /*//////////////////////////////////////////////////////////////
                            PROTECTED FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Called by a owner to convert all the staked ETH to get lpETH
     */
    function convertAll() external onlyAuthorized {
        if (block.timestamp - loopActivation <= TIMELOCK) {
            revert LoopNotActivated();
        }

        // deposits all the ETH to lpETH contract. Receives lpETH back
        lpETH.deposit{value: totalSupply}(address(this));
        totalLpETH = lpETH.balanceOf(address(this));

        // Claims of lpETH can start immediately after conversion.
        startClaimDate = uint32(block.timestamp);

        emit Converted(totalSupply, totalLpETH);
    }

    /**
     * @notice Sets a new owner
     * @param _owner address of the new owner
     */
    function setOwner(address _owner) external onlyAuthorized {
        owner = _owner;

        emit OwnerUpdated(_owner);
    }

    /**
     * @notice Sets the lpETH contract address
     * @param _loopAddress address of the lpETH contract
     * @dev Can only be set once before 120 days have passed from deployment.
     *      After that users can only withdraw ETH.
     */
    function setLoopAddresses(address _loopAddress, address _vaultAddress)
        external
        onlyAuthorized
        onlyBeforeDate(loopActivation)
    {
        lpETH = ILpETH(_loopAddress);
        lpETHVault = ILpETHVault(_vaultAddress);
        loopActivation = uint32(block.timestamp);

        emit LoopAddressesUpdated(_loopAddress, _vaultAddress);
    }

    /**
     * @dev Allows the owner to recover other ERC20s mistakingly sent to this contract
     */
    function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyAuthorized {
        if (tokenAddress == address(lpETH)) {
            revert NotValidToken();
        }
        IERC20(tokenAddress).safeTransfer(owner, tokenAmount);

        emit Recovered(tokenAddress, tokenAmount);
    }

    /**
     * Reverts when a contract receives plain Ether (without data)
     */
    receive() external payable {
        revert();
    }

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyAuthorized() {
        if (msg.sender != owner) {
            revert NotAuthorized();
        }
        _;
    }

    modifier onlyAfterDate(uint256 limitDate) {
        if (block.timestamp <= limitDate) {
            revert CurrentlyNotPossible();
        }
        _;
    }

    modifier onlyBeforeDate(uint256 limitDate) {
        if (block.timestamp >= limitDate) {
            revert NoLongerPossible();
        }
        _;
    }
}
