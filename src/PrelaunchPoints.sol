// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import {ILpETH, IERC20} from "./interfaces/ILpETH.sol";
import {ILpETHVault} from "./interfaces/ILpETHVault.sol";

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
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public immutable exchangeProxy;

    address public owner;

    uint256 public totalSupply;
    mapping(address => bool) public isTokenAllowed;
    uint256 public totalLpETH;

    uint32 public loopActivation;
    uint32 public startClaimDate;
    uint32 public constant TIMELOCK = 7 days;

    mapping(address => mapping(address => uint256)) public balances;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Locked(address indexed user, uint256 amount, address token, bytes32 indexed referral);
    event StakedVault(address indexed user, uint256 amount);
    event Converted(uint256 amountETH, uint256 amountlpETH);
    event Withdrawn(address indexed user, address token, uint256 amount);
    event Claimed(address indexed user, address token, uint256 reward);
    event Recovered(address token, uint256 amount);
    event OwnerUpdated(address newOwner);
    event LoopAddressesUpdated(address loopAddress, address vaultAddress);
    event SwappedTokens(address sellToken, uint256 buyETHAmount);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error NothingToClaim();
    error CannotLockBoth();
    error TokenNotAllowed();
    error CannotStakeZero();
    error CannotWithdrawZero();
    error FailedToSendEther();
    error SwapCallFailed();
    error WrongDataTokens();
    error WrongDataAmount();
    error LoopNotActivated();
    error NotValidToken();
    error NotAuthorized();
    error CurrentlyNotPossible();
    error NoLongerPossible();

    /*//////////////////////////////////////////////////////////////
                             INITIALIZATION
    //////////////////////////////////////////////////////////////*/
    /**
     * @param _exchangeProxy address of the 0x protocol exchange proxy
     * @param _allowedTokens list of token addresses to allow for locking
     */
    constructor(address _exchangeProxy, address[] memory _allowedTokens) {
        owner = msg.sender;
        exchangeProxy = _exchangeProxy;
        loopActivation = uint32(block.timestamp + 120 days);
        startClaimDate = 4294967295; // Max uint32 ~ year 2107

        // Allow intital list of tokens
        uint256 length = _allowedTokens.length;
        for (uint256 i = 0; i < length;) {
            isTokenAllowed[_allowedTokens[i]] = true;
            unchecked {
                i++;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                            STAKE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Locks ETH
     * @param _referral  info of the referral. This value will be processed in the backend.
     */
    function lockETH(bytes32 _referral) external payable {
        _processLock(ETH, msg.value, msg.sender, _referral);
    }

    /**
     * @notice Locks ETH for a given address
     * @param _for       address for which ETH is locked
     * @param _referral  info of the referral. This value will be processed in the backend.
     */
    function lockETHFor(address _for, bytes32 _referral) external payable {
        _processLock(ETH, msg.value, _for, _referral);
    }

    /**
     * @notice Locks a valid token
     * @param _token     address of token to lock
     * @param _amount    amount of token to lock
     * @param _referral  info of the referral. This value will be processed in the backend.
     */
    function lock(address _token, uint256 _amount, bytes32 _referral) external {
        _processLock(_token, _amount, msg.sender, _referral);
    }

    /**
     * @notice Locks a valid token for a given address
     * @param _token     address of token to lock
     * @param _amount    amount of token to lock
     * @param _for       address for which ETH is locked
     * @param _referral  info of the referral. This value will be processed in the backend.
     */
    function lockFor(address _token, uint256 _amount, address _for, bytes32 _referral) external {
        _processLock(_token, _amount, _for, _referral);
    }

    /**
     * @dev Generic internal locking function that updates rewards based on
     *      previous balances, then update balances.
     * @param _token       Address of the token to lock
     * @param _amount      Units of ETH or token to add to the users balance
     * @param _receiver    Address of user who will receive the stake
     * @param _referral    Address of the referral user
     */
    function _processLock(address _token, uint256 _amount, address _receiver, bytes32 _referral)
        internal
        onlyBeforeDate(loopActivation)
    {
        if (_amount == 0) {
            revert CannotStakeZero();
        }
        if (_token == ETH) {
            totalSupply = totalSupply + _amount;
        } else {
            if (!isTokenAllowed[_token]) {
                revert TokenNotAllowed();
            }
            IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        }

        balances[_token][_receiver] = balances[_token][_receiver] + _amount;
        emit Locked(_receiver, _amount, _token, _referral);
    }

    /*//////////////////////////////////////////////////////////////
                        CLAIM AND WITHDRAW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Called by a user to get their vested lpETH
     * @param _token      Address of the token to convert to lpETH
     * @param _data       Swap data obtained from 0x API
     */
    function claim(address _token, bytes calldata _data) external onlyAfterDate(startClaimDate) {
        _claim(_token, msg.sender, _data);
    }

    /**
     * @dev Called by a user to get their vested lpETH and stake them in a
     *      Loop vault for extra rewards
     * @param _token      Address of the token to convert to lpETH
     * @param _data       Swap data obtained from 0x API
     */
    function claimAndStake(address _token, bytes calldata _data) external onlyAfterDate(startClaimDate) {
        uint256 claimedAmount = _claim(_token, address(this), _data);
        lpETH.approve(address(lpETHVault), claimedAmount);
        lpETHVault.stake(claimedAmount, msg.sender);

        emit StakedVault(msg.sender, claimedAmount);
    }

    /**
     * @dev Claim logic. If necessary converts token to ETH before depositing into lpETH contract.
     */
    function _claim(address _token, address _receiver, bytes calldata _data) internal returns (uint256 claimedAmount) {
        uint256 userStake = balances[_token][msg.sender];
        if (userStake == 0) {
                revert NothingToClaim();
            }
        if (_token == ETH) {
            claimedAmount = userStake.mulDiv(totalLpETH, totalSupply);
            balances[_token][msg.sender] = 0;
            lpETH.safeTransfer(_receiver, claimedAmount);
        } else {
            _validateData(_token, userStake, _data);
            balances[_token][msg.sender] = 0;
            
            // Swap token to ETH
            uint256 userETH = address(this).balance;
            _fillQuote(IERC20(_token), userStake, _data);
            claimedAmount = address(this).balance - userETH;

            // Convert swapped ETH to lpETH (1 to 1 conversion)
            lpETH.deposit{value: claimedAmount}(_receiver);
        }
        emit Claimed(msg.sender, _token, claimedAmount);
    }

    /**
     * @dev Called by a staker to withdraw all their ETH
     * Note Can only be called after the loop address is set and before claiming lpETH,
     * i.e. for at least TIMELOCK
     * @param _token      Address of the token to withdraw
     */
    function withdraw(address _token) external onlyAfterDate(loopActivation) onlyBeforeDate(startClaimDate) {
        uint256 lockedAmount = balances[_token][msg.sender];
        balances[_token][msg.sender] = 0;

        if (lockedAmount == 0) {
            revert CannotWithdrawZero();
        }
        if (_token == ETH) {
            totalSupply = totalSupply - lockedAmount;

            (bool sent,) = msg.sender.call{value: lockedAmount}("");

            if (!sent) {
                revert FailedToSendEther();
            }
        } else {
            IERC20(_token).safeTransfer(msg.sender, lockedAmount);
        }

        emit Withdrawn(msg.sender, _token, lockedAmount);
    }

    /*//////////////////////////////////////////////////////////////
                            PROTECTED FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Called by a owner to convert all the locked ETH to get lpETH
     */
    function convertAllETH() external onlyAuthorized {
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
     * @param _token address of a wrapped LRT token
     * @dev ONLY add wrapped LRT tokens. Contract not compatible with rebase tokens.
     */
    function allowToken(address _token) external onlyAuthorized {
        isTokenAllowed[_token] = true;
    }

    /**
     * @dev Allows the owner to recover other ERC20s mistakingly sent to this contract
     */
    function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyAuthorized {
        if (tokenAddress == address(lpETH) || isTokenAllowed[tokenAddress]) {
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
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Validates the data sent from 0x API to match desired behaviour
     * @param _token     address of the token to sell
     * @param _amount    amount of token to sell
     * @param _data      swap data from 0x API
     */
    function _validateData(address _token, uint256 _amount, bytes calldata _data) internal pure {
        (
            address inputToken,
            address outputToken,
            uint256 inputTokenAmount,
            /* uint256 minOutputTokenAmount */
        ) = abi.decode(_data[1:5], (address, address, uint256, uint256));

        if (inputToken != _token || outputToken != ETH) {
            revert WrongDataTokens();
        }
        if (inputTokenAmount != _amount) {
            revert WrongDataAmount();
        }
    }

    /**
     *
     * @param _sellToken     The `sellTokenAddress` field from the API response.
     * @param _amount       The `sellAmount` field from the API response.
     * @param _swapCallData  The `data` field from the API response.
     */
    function _fillQuote(IERC20 _sellToken, uint256 _amount, bytes calldata _swapCallData) internal {
        // Track our balance of the buyToken to determine how much we've bought.
        uint256 boughtETHAmount = address(this).balance;

        require(_sellToken.approve(exchangeProxy, _amount));

        (bool success,) = payable(exchangeProxy).call{value: 0}(_swapCallData);
        if (!success) {
            revert SwapCallFailed();
        }

        // Use our current buyToken balance to determine how much we've bought.
        boughtETHAmount = address(this).balance - boughtETHAmount;
        emit SwappedTokens(address(_sellToken), boughtETHAmount);
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
