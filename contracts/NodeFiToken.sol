// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title NodeFi Token (NODE)
/// @notice ERC20 with fixed‐floor & cap, deflationary burns, and buyback fees on transfers
contract NodeFiToken is ERC20, Ownable {
    /// @notice Floor: 622 000 000 NODE
    uint256 public constant MIN_SUPPLY = 622_000_000 * 1e18;
    /// @notice Cap: 690 000 000 NODE
    uint256 public constant MAX_SUPPLY = 690_000_000 * 1e18;

    /// @notice Burn fee (in BPS) on each transfer
    uint16 public transferBurnBps;
    /// @notice Buyback fee (in BPS) on each transfer
    uint16 public transferBuybackBps;
    /// @notice Recipient of the buyback portion
    address public buybackReceiver;

    event TransferBurnBpsUpdated(uint16 newBps);
    event TransferBuybackBpsUpdated(uint16 newBps);
    event BuybackReceiverUpdated(address newReceiver);
    event FeeTaken(address indexed from, uint256 amountBurned, uint256 amountToTreasury);


    /// @param initialHolder      Receives the MIN_SUPPLY at deployment
    /// @param _buybackReceiver   Receives the buyback slice of each transfer
    /// @param _burnBps           Initial burn rate in BPS (≤1000)
    /// @param _buybackBps        Initial buyback rate in BPS (≤1000)
    constructor(
        address initialHolder,
        address _buybackReceiver,
        uint16 _burnBps,
        uint16 _buybackBps
    )
        ERC20("NodeFi Token", "NODE")
        Ownable(initialHolder)
    {
        require(initialHolder != address(0),      "NFT: zero holder");
        require(_buybackReceiver != address(0),   "NFT: zero receiver");
        require(_burnBps + _buybackBps <= 1000,   "NFT: max 10% fee");

        transferBurnBps     = _burnBps;
        transferBuybackBps  = _buybackBps;
        buybackReceiver     = _buybackReceiver;

        // Mint floor supply to initial holder
        _mint(initialHolder, MIN_SUPPLY);
    }

    /// @notice Owner can mint up to the MAX_SUPPLY cap
    function mint(address to, uint256 amount) external onlyOwner {
        require(totalSupply() + amount <= MAX_SUPPLY, "NFT: cap exceeded");
        _mint(to, amount);
    }

    /// @notice Adjust the burn fee (BPS). sum(burn, buyback) ≤1000
    function setTransferBurnBps(uint16 bps) external onlyOwner {
        require(bps + transferBuybackBps <= 1000, "NFT: max 10% fee");
        transferBurnBps = bps;
        emit TransferBurnBpsUpdated(bps);
    }

    /// @notice Adjust the buyback fee (BPS). sum(burn, buyback) ≤1000
    function setTransferBuybackBps(uint16 bps) external onlyOwner {
        require(bps + transferBurnBps <= 1000, "NFT: max 10% fee");
        transferBuybackBps = bps;
        emit TransferBuybackBpsUpdated(bps);
    }

    /// @notice Change the buyback receiver
    function setBuybackReceiver(address receiver) external onlyOwner {
        require(receiver != address(0), "NFT: zero receiver");
        buybackReceiver = receiver;
        emit BuybackReceiverUpdated(receiver);
    }

    /// @dev Override transfer to apply burn + buyback
    function transfer(address to, uint256 amount)
        public
        override
        returns (bool)
    {
        _transferWithFee(_msgSender(), to, amount);
        return true;
    }

    /// @dev Override transferFrom to apply burn + buyback
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        _spendAllowance(from, _msgSender(), amount);
        _transferWithFee(from, to, amount);
        return true;
    }

    /// @dev Internal logic: burns and sends buyback slice, then forwards remainder
    function _transferWithFee(
        address sender,
        address recipient,
        uint256 amount
    ) internal {
        uint16 totalFeeBps = transferBurnBps + transferBuybackBps;

        if (sender != owner() && totalFeeBps > 0) {
            // compute portions
            uint256 burnAmt    = (amount * transferBurnBps) / 10000;
            uint256 buybackAmt = (amount * transferBuybackBps) / 10000;
            uint256 sendAmt    = amount - burnAmt - buybackAmt;

            if (burnAmt > 0) {
                _burn(sender, burnAmt);
            }
            if (buybackAmt > 0) {
                super._transfer(sender, buybackReceiver, buybackAmt);
            }
            super._transfer(sender, recipient, sendAmt);
        } else {
            // no fees for owner or if fees disabled
            super._transfer(sender, recipient, amount);
        }
    }
}
