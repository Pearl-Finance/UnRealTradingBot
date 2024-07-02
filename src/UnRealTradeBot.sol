// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IQuoter} from "./interfaces/IQuoter.sol";
import {ISwapRouter} from "./interfaces/ISwapRouter.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title UnRealTradeBot
 * @author c-n-o-t-e
 * @dev Contract is used to trade tokens in pools in pearl dex in batches/paths
 */
contract UnRealTradeBot is Ownable {
    using SafeERC20 for IERC20;

    IQuoter quoter;
    ISwapRouter router;

    bool public isFirstPath;
    uint64 public slippage;
    uint256 constant PERCENTAGE = 1_000;

    bytes[] public firstPath;
    bytes[] public secondPath;

    struct PathInfo {
        bool isPath;
        uint256 amountToTrade;
    }

    mapping(bytes => PathInfo) public pathInfo;

    error UnRealTradeBot_InvalidID();
    error UnRealTradeBot_LowBalance();
    error UnRealTradeBot_MismatchLength();
    error UnRealTradeBot_PathAlreadyExist();
    error UnRealTradeBot_PathDoesNotExist();
    error UnRealTradeBot_BelowAmountOutMinimum();
    error UnRealTradeBot_MustBeAddedWhenFirstPathIsTrue();

    constructor(
        bytes[] memory _firstPath,
        bytes[] memory _secondPath,
        ISwapRouter _router,
        IQuoter _quoter,
        uint256 _amountToTrade
    ) Ownable(msg.sender) {
        if (_firstPath.length != _secondPath.length) revert UnRealTradeBot_MismatchLength();
        isFirstPath = true;

        router = _router;
        quoter = _quoter;

        for (uint256 i = 0; i < _firstPath.length;) {
            pathInfo[_firstPath[i]].isPath = true;
            pathInfo[_secondPath[i]].isPath = true;
            pathInfo[_firstPath[i]].amountToTrade = _amountToTrade;

            unchecked {
                i++;
            }
        }

        firstPath = _firstPath;
        secondPath = _secondPath;
    }

    function updatePaths(bytes[] memory _firstPath, bytes[] memory _secondPath, uint256[] memory _amountToTrade)
        external
        onlyOwner
    {
        if (_firstPath.length != _secondPath.length || _secondPath.length != _amountToTrade.length) {
            revert UnRealTradeBot_MismatchLength();
        }
        bytes[] memory fPath = firstPath;
        bytes[] memory sPath = secondPath;
        uint256 length = fPath.length;

        for (uint256 i = 0; i < length;) {
            pathInfo[fPath[i]].isPath = false;
            pathInfo[sPath[i]].isPath = false;

            unchecked {
                i++;
            }
        }

        for (uint256 i = 0; i < _firstPath.length;) {
            pathInfo[_firstPath[i]].isPath = true;
            pathInfo[_secondPath[i]].isPath = true;
            pathInfo[_firstPath[i]].amountToTrade = _amountToTrade[i];

            unchecked {
                i++;
            }
        }

        firstPath = _firstPath;
        secondPath = _secondPath;
    }

    function updateAmountToTrade(bytes[] memory _path, uint256[] memory _amountToTrade) external onlyOwner {
        if (_path.length != _amountToTrade.length) revert UnRealTradeBot_MismatchLength();

        for (uint256 i = 0; i < _path.length;) {
            if (!pathInfo[_path[i]].isPath) revert UnRealTradeBot_PathDoesNotExist();

            if (IERC20(_firstAddressInPath(_path[i])).balanceOf(address(this)) < _amountToTrade[i]) {
                revert UnRealTradeBot_LowBalance();
            }

            pathInfo[_path[i]].amountToTrade = _amountToTrade[i];
            unchecked {
                i++;
            }
        }
    }

    function addPaths(bytes[] memory _firstPath, bytes[] memory _secondPath, uint256[] memory _amountToTrade)
        external
        onlyOwner
    {
        if (!isFirstPath) revert UnRealTradeBot_MustBeAddedWhenFirstPathIsTrue();
        if (_firstPath.length != _secondPath.length) revert UnRealTradeBot_MismatchLength();

        for (uint256 i = 0; i < _firstPath.length;) {
            if (pathInfo[_firstPath[i]].isPath) revert UnRealTradeBot_PathAlreadyExist();

            pathInfo[_firstPath[i]].isPath = true;
            pathInfo[_secondPath[i]].isPath = true;
            pathInfo[_firstPath[i]].amountToTrade = _amountToTrade[i];

            firstPath.push(_firstPath[i]);
            secondPath.push(_secondPath[i]);

            unchecked {
                i++;
            }
        }
    }

    function removePaths(uint256 id) external onlyOwner {
        bytes[] memory fPath = firstPath;
        bytes[] memory sPath = secondPath;
        if (fPath.length - 1 < id) revert UnRealTradeBot_InvalidID();

        pathInfo[fPath[id]].isPath = false;
        pathInfo[sPath[id]].isPath = false;

        if (fPath.length - 1 != id) {
            bytes memory swappablePath = fPath[fPath.length - 1];
            bytes memory swappablePath0 = sPath[fPath.length - 1];

            fPath[fPath.length - 1] = fPath[id];
            sPath[fPath.length - 1] = sPath[id];

            fPath[id] = swappablePath;
            sPath[id] = swappablePath0;
        }

        firstPath = fPath;
        secondPath = sPath;

        firstPath.pop();
        secondPath.pop();
    }

    function withdraw(address _token, address _recipient, uint256 _amout) external onlyOwner {
        IERC20(_token).transfer(_recipient, _amout);
    }

    /**
     * First Path[]
     * USTB/arcUSD Fee:100 -> arcUSD/UKRE Fee:500
     * USTB/Pearl Fee:10000 -> Pearl/CAVIAR Fee:500
     * USTB/WREETH Fee:3000 -> WREETH/Real Fee:3000
     * DAI/USTB Fee:100 -> USTB/MORE Fee:100
     *
     * Second Path[]
     * USTB/arcUSD Fee:100 <- arcUSD/UKRE Fee:500
     * USTB/Pearl Fee:10000 <- Pearl/CAVIAR Fee:500
     * USTB/WREETH Fee:3000 <- WREETH/Real Fee:3000
     * DAI/USTB Fee:100 <- USTB/MORE Fee:100
     */
    function runTrades() external {
        bytes[] memory fPath = firstPath;
        uint256 length = fPath.length;

        if (isFirstPath) {
            for (uint256 i = 0; i < length;) {
                _swap(fPath[i], pathInfo[fPath[i]].amountToTrade, i, true);
                unchecked {
                    i++;
                }
            }
            isFirstPath = false;
        } else {
            for (uint256 i = 0; i < length;) {
                _swap(secondPath[i], pathInfo[secondPath[i]].amountToTrade, i, false);
                unchecked {
                    i++;
                }
            }
            isFirstPath = true;
        }
    }

    function getAmountOut(bytes memory path, uint256 amountIn) public returns (uint256 amountOut) {
        (amountOut,,,) = quoter.quoteExactInput(path, amountIn);
    }

    function setSlippage(uint64 _slippage) external onlyOwner {
        slippage = _slippage;
    }

    function _swap(bytes memory _path, uint256 _amountIn, uint256 _index, bool _isFirstPath) internal {
        address pathTokenIn = _firstAddressInPath(_path);
        address pathTokenOut = _lastAddressInPath(_path);
        IERC20 token = IERC20(pathTokenIn);

        if (token.balanceOf(address(this)) < _amountIn) revert UnRealTradeBot_LowBalance();
        uint256 tokenOutBalanceBeforeTx = IERC20(pathTokenOut).balanceOf(address(this));

        uint256 amountOut = getAmountOut(_path, _amountIn);
        uint256 _amountOutMinimum = (amountOut * slippage) / PERCENTAGE;

        ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
            path: _path,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: _amountIn,
            amountOutMinimum: _amountOutMinimum
        });

        token.forceApprove(address(router), _amountIn);
        amountOut = router.exactInputFeeOnTransfer(params);
        token.forceApprove(address(router), 0);

        uint256 amountRecieved = IERC20(pathTokenOut).balanceOf(address(this)) - tokenOutBalanceBeforeTx;

        if (amountRecieved < _amountOutMinimum) {
            revert UnRealTradeBot_BelowAmountOutMinimum();
        }

        if (_isFirstPath) pathInfo[secondPath[_index]].amountToTrade = amountRecieved;
        else pathInfo[firstPath[_index]].amountToTrade = amountOut;
    }

    function _firstAddressInPath(bytes memory path) internal pure returns (address firstAddress) {
        require(path.length >= 20, "OB");
        assembly {
            firstAddress := shr(96, mload(add(path, 0x20)))
        }
    }

    function _lastAddressInPath(bytes memory path) internal pure returns (address lastAddress) {
        require(path.length >= 20, "OB");
        assembly {
            lastAddress := shr(96, mload(add(add(path, mload(path)), 12)))
        }
    }
}
