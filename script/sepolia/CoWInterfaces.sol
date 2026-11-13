// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

library CoWOrder {
    struct Data {
        address sellToken;
        address buyToken;
        address receiver;
        uint256 sellAmount;
        uint256 buyAmount;
        uint32 validTo;
        bytes32 appData;
        uint256 feeAmount;
        bytes32 kind;
        bool partiallyFillable;
        bytes32 sellTokenBalance;
        bytes32 buyTokenBalance;
    }

    bytes32 internal constant TYPEHASH = keccak256(
        "Order(address sellToken,address buyToken,address receiver,uint256 sellAmount,uint256 buyAmount,uint32 validTo,bytes32 appData,uint256 feeAmount,string kind,bool partiallyFillable,string sellTokenBalance,string buyTokenBalance)"
    );

    function digest(Data memory order, bytes32 domain) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(hex"1901", domain, keccak256(abi.encode(TYPEHASH, order))));
    }
}

interface ICoWSettlement {
    function domainSeparator() external view returns (bytes32);
    function preSignature(bytes calldata uid) external view returns (uint256);
}

interface IOrderSigner {
    function signOrder(CoWOrder.Data calldata order, uint32 validDuration, uint256 feeAmountBP) external;
    function unsignOrder(CoWOrder.Data calldata order) external;
}

interface ICoWFallback {
    function setDomainVerifier(bytes32 domain, address verifier) external;
    function domainVerifiers(address safe, bytes32 domain) external view returns (address);
    function isValidSignature(bytes32 hash, bytes calldata signature) external view returns (bytes4);
}

interface IComposableCoW {
    struct Params {
        address handler;
        bytes32 salt;
        bytes staticInput;
    }
    function createWithContext(Params calldata params, address factory, bytes calldata data, bool dispatch) external;
    function remove(bytes32 digest) external;
    function getTradeableOrderWithSignature(
        address owner,
        Params calldata params,
        bytes calldata input,
        bytes32[] calldata proof
    ) external view returns (CoWOrder.Data memory order, bytes memory signature);
}
