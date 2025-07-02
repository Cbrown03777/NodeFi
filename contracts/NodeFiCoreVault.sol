// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

interface IRewardsDistributor {
    function vault() external view returns (address);
    function onVaultStake(address user, uint256 shares) external;
    function onVaultUnstake(address user, uint256 shares) external;
}

contract NodeFiCoreVault is
    Initializable,
    ERC20Upgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @notice The token this vault accepts
    address public underlying;
    uint8  public underlyingDecimals;

    /// @notice Dust remainder from share‐minting arithmetic
    uint256 public shareDust;

    /// @notice Total underlying tokens held in the vault
    uint256 public totalUnderlying;

    /// @notice Rewards distributor hook
    address public rewardsDistributor;

    /// @notice Initial slippage, in BPS (0–1000)
    uint16  public initialSlippageBps;

    uint256[50] private __gap;

    event UnderlyingReceived(address indexed user, uint256 amount);
    event UnexpectedEtherReceived(address indexed user, uint256 amount);
    event FallbackCalled(address indexed user, bytes data, uint256 value);
    event Staked(address indexed user, uint256 amount, uint256 shares);
    event ShareDustUpdated(uint256 indexed epoch, uint256 dust);
    event TotalUnderlyingUpdated(uint256 indexed epoch, uint256 totalUnderlying);

    event Unstaked(
        address indexed user,
        uint256 amount,
        uint256 shares,
        uint256 newShares,
        uint256 remainder
    );
    
    event DistributorCallFailed(address indexed user, bool isStake);

    function initialize(address _underlying) external initializer {
        __ERC20_init("NodeFi CoreVault", "nCORE");
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        require(_underlying != address(0), "CoreVault: zero underlying");
        underlying = _underlying;

        // verify ERC20 metadata
        try IERC20MetadataUpgradeable(_underlying).decimals() returns (uint8 d) {
            underlyingDecimals = d;
        } catch {
            revert("CoreVault: invalid ERC20 metadata");
        }
        // verify ERC20 supply
        try IERC20Upgradeable(_underlying).totalSupply() returns (uint256) {} catch {
            revert("CoreVault: invalid ERC20 supply");
        }

        initialSlippageBps = 0;
    }

    receive() external payable {
        if (underlying != address(0)) {
            (bool ok,) = msg.sender.call{ value: msg.value }("");
            if (ok) emit UnexpectedEtherReceived(msg.sender, msg.value);
        } else {
            emit UnderlyingReceived(msg.sender, msg.value);
        }
    }

    fallback() external payable {
        emit FallbackCalled(msg.sender, msg.data, msg.value);
        if (msg.value > 0 && underlying != address(0)) {
            (bool ok,) = msg.sender.call{ value: msg.value }("");
            require(ok, "CoreVault: refund failed");
        }
    }

    function stake(uint256 amount)
        external
        payable
        whenNotPaused
        nonReentrant
    {
        uint256 depositAmt = _handleDeposit(amount);

        uint256 supply = totalSupply();
        if (supply > 0) {
            // track dust from integer division
            uint256 dust = (supply * depositAmt) % totalUnderlying;
            shareDust += dust;
        }

        uint256 shares = _calculateShares(depositAmt);

        totalUnderlying += depositAmt;
        _mint(msg.sender, shares);
        _notifyStake(msg.sender, shares);

        emit Staked(msg.sender, depositAmt, shares);
    }

    function unstake(uint256 shares)
        external
        whenNotPaused
        nonReentrant
    {
        require(shares > 0, "CoreVault: zero shares");
        require(totalUnderlying > 0, "CoreVault: no underlying");

        uint256 supply = totalSupply();
        uint256 currentUnderlying = totalUnderlying;

        uint256 amount = (currentUnderlying * shares) / supply;
        uint256 remainder = currentUnderlying * shares - amount * supply;
        require(currentUnderlying >= amount, "CoreVault: underflow");

        totalUnderlying = currentUnderlying - amount;
        _burn(msg.sender, shares);
        _notifyUnstake(msg.sender, shares);
        _transferOut(msg.sender, amount);

        uint256 newShares = balanceOf(msg.sender);
        emit Unstaked(msg.sender, amount, shares, newShares, remainder);
    }

    function _handleDeposit(uint256 amount)
        private
        returns (uint256)
    {
        if (underlying == address(0)) {
            require(msg.value == amount, "CoreVault: ETH value mismatch");
            return amount;
        } else {
            require(msg.value == 0, "CoreVault: no ETH accepted");
            IERC20Upgradeable(underlying).safeTransferFrom(
                msg.sender, address(this), amount
            );
            emit UnderlyingReceived(msg.sender, amount);
            return amount;
        }
    }

    function _calculateShares(uint256 amount)
        private
        view
        returns (uint256)
    {
        uint256 supply = totalSupply();
        if (supply == 0) {
            // first staker: apply slippage
            return (amount * (10000 - initialSlippageBps)) / 10000;
        }
        return (supply * amount) / totalUnderlying;
    }

    function _notifyStake(address user, uint256 shares) private {
        try IRewardsDistributor(rewardsDistributor).onVaultStake(user, shares) {} 
        catch {
            emit DistributorCallFailed(user, true);
        }
    }

    function _notifyUnstake(address user, uint256 shares) private {
        try IRewardsDistributor(rewardsDistributor).onVaultUnstake(user, shares) {} 
        catch {
            emit DistributorCallFailed(user, false);
        }
    }

    function _transferOut(address to, uint256 amount) private {
        if (underlying == address(0)) {
            (bool ok,) = to.call{ value: amount }("");
            require(ok, "CoreVault: ETH send failed");
        } else {
            IERC20Upgradeable(underlying).safeTransfer(to, amount);
        }
    }

    function setRewardsDistributor(address dist) external onlyOwner whenNotPaused {
        require(dist != address(0), "CoreVault: zero distributor");
        require(
            IRewardsDistributor(dist).vault() == address(this),
            "CoreVault: bad distributor"
        );
        rewardsDistributor = dist;
    }

    function setInitialSlippageBps(uint16 bps)
        external
        onlyOwner
        whenNotPaused
    {
        require(bps <= 1000, "CoreVault: max 10% slippage");
        initialSlippageBps = bps;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}

