// SPDX-License-Identifier: MIT AND UNLICENSED
pragma solidity ^0.8.0;

// File @chainlink/contracts/src/v0.8/vendor/BufferChainlink.sol@v1.2.0
/**
 * @dev A library for working with mutable byte buffers in Solidity.
 *
 * Byte buffers are mutable and expandable, and provide a variety of primitives
 * for writing to them. At any time you can fetch a bytes object containing the
 * current contents of the buffer. The bytes object should not be stored between
 * operations, as it may change due to resizing of the buffer.
 */
library BufferChainlink {
  /**
   * @dev Represents a mutable buffer. Buffers have a current value (buf) and
   *      a capacity. The capacity may be longer than the current value, in
   *      which case it can be extended without the need to allocate more memory.
   */
  struct buffer {
    bytes buf;
    uint256 capacity;
  }

  /**
   * @dev Initializes a buffer with an initial capacity.
   * @param buf The buffer to initialize.
   * @param capacity The number of bytes of space to allocate the buffer.
   * @return The buffer, for chaining.
   */
  function init(buffer memory buf, uint256 capacity) internal pure returns (buffer memory) {
    if (capacity % 32 != 0) {
      capacity += 32 - (capacity % 32);
    }
    // Allocate space for the buffer data
    buf.capacity = capacity;
    assembly {
      let ptr := mload(0x40)
      mstore(buf, ptr)
      mstore(ptr, 0)
      mstore(0x40, add(32, add(ptr, capacity)))
    }
    return buf;
  }

  /**
   * @dev Initializes a new buffer from an existing bytes object.
   *      Changes to the buffer may mutate the original value.
   * @param b The bytes object to initialize the buffer with.
   * @return A new buffer.
   */
  function fromBytes(bytes memory b) internal pure returns (buffer memory) {
    buffer memory buf;
    buf.buf = b;
    buf.capacity = b.length;
    return buf;
  }

  function resize(buffer memory buf, uint256 capacity) private pure {
    bytes memory oldbuf = buf.buf;
    init(buf, capacity);
    append(buf, oldbuf);
  }

  function max(uint256 a, uint256 b) private pure returns (uint256) {
    if (a > b) {
      return a;
    }
    return b;
  }

  /**
   * @dev Sets buffer length to 0.
   * @param buf The buffer to truncate.
   * @return The original buffer, for chaining..
   */
  function truncate(buffer memory buf) internal pure returns (buffer memory) {
    assembly {
      let bufptr := mload(buf)
      mstore(bufptr, 0)
    }
    return buf;
  }

  /**
   * @dev Writes a byte string to a buffer. Resizes if doing so would exceed
   *      the capacity of the buffer.
   * @param buf The buffer to append to.
   * @param off The start offset to write to.
   * @param data The data to append.
   * @param len The number of bytes to copy.
   * @return The original buffer, for chaining.
   */
  function write(
    buffer memory buf,
    uint256 off,
    bytes memory data,
    uint256 len
  ) internal pure returns (buffer memory) {
    require(len <= data.length);

    if (off + len > buf.capacity) {
      resize(buf, max(buf.capacity, len + off) * 2);
    }

    uint256 dest;
    uint256 src;
    assembly {
      // Memory address of the buffer data
      let bufptr := mload(buf)
      // Length of existing buffer data
      let buflen := mload(bufptr)
      // Start address = buffer address + offset + sizeof(buffer length)
      dest := add(add(bufptr, 32), off)
      // Update buffer length if we're extending it
      if gt(add(len, off), buflen) {
        mstore(bufptr, add(len, off))
      }
      src := add(data, 32)
    }

    // Copy word-length chunks while possible
    for (; len >= 32; len -= 32) {
      assembly {
        mstore(dest, mload(src))
      }
      dest += 32;
      src += 32;
    }

    // Copy remaining bytes
    unchecked {
      uint256 mask = (256**(32 - len)) - 1;
      assembly {
        let srcpart := and(mload(src), not(mask))
        let destpart := and(mload(dest), mask)
        mstore(dest, or(destpart, srcpart))
      }
    }

    return buf;
  }

  /**
   * @dev Appends a byte string to a buffer. Resizes if doing so would exceed
   *      the capacity of the buffer.
   * @param buf The buffer to append to.
   * @param data The data to append.
   * @param len The number of bytes to copy.
   * @return The original buffer, for chaining.
   */
  function append(
    buffer memory buf,
    bytes memory data,
    uint256 len
  ) internal pure returns (buffer memory) {
    return write(buf, buf.buf.length, data, len);
  }

  /**
   * @dev Appends a byte string to a buffer. Resizes if doing so would exceed
   *      the capacity of the buffer.
   * @param buf The buffer to append to.
   * @param data The data to append.
   * @return The original buffer, for chaining.
   */
  function append(buffer memory buf, bytes memory data) internal pure returns (buffer memory) {
    return write(buf, buf.buf.length, data, data.length);
  }

  /**
   * @dev Writes a byte to the buffer. Resizes if doing so would exceed the
   *      capacity of the buffer.
   * @param buf The buffer to append to.
   * @param off The offset to write the byte at.
   * @param data The data to append.
   * @return The original buffer, for chaining.
   */
  function writeUint8(
    buffer memory buf,
    uint256 off,
    uint8 data
  ) internal pure returns (buffer memory) {
    if (off >= buf.capacity) {
      resize(buf, buf.capacity * 2);
    }

    assembly {
      // Memory address of the buffer data
      let bufptr := mload(buf)
      // Length of existing buffer data
      let buflen := mload(bufptr)
      // Address = buffer address + sizeof(buffer length) + off
      let dest := add(add(bufptr, off), 32)
      mstore8(dest, data)
      // Update buffer length if we extended it
      if eq(off, buflen) {
        mstore(bufptr, add(buflen, 1))
      }
    }
    return buf;
  }

  /**
   * @dev Appends a byte to the buffer. Resizes if doing so would exceed the
   *      capacity of the buffer.
   * @param buf The buffer to append to.
   * @param data The data to append.
   * @return The original buffer, for chaining.
   */
  function appendUint8(buffer memory buf, uint8 data) internal pure returns (buffer memory) {
    return writeUint8(buf, buf.buf.length, data);
  }

  /**
   * @dev Writes up to 32 bytes to the buffer. Resizes if doing so would
   *      exceed the capacity of the buffer.
   * @param buf The buffer to append to.
   * @param off The offset to write at.
   * @param data The data to append.
   * @param len The number of bytes to write (left-aligned).
   * @return The original buffer, for chaining.
   */
  function write(
    buffer memory buf,
    uint256 off,
    bytes32 data,
    uint256 len
  ) private pure returns (buffer memory) {
    if (len + off > buf.capacity) {
      resize(buf, (len + off) * 2);
    }

    unchecked {
      uint256 mask = (256**len) - 1;
      // Right-align data
      data = data >> (8 * (32 - len));
      assembly {
        // Memory address of the buffer data
        let bufptr := mload(buf)
        // Address = buffer address + sizeof(buffer length) + off + len
        let dest := add(add(bufptr, off), len)
        mstore(dest, or(and(mload(dest), not(mask)), data))
        // Update buffer length if we extended it
        if gt(add(off, len), mload(bufptr)) {
          mstore(bufptr, add(off, len))
        }
      }
    }
    return buf;
  }

  /**
   * @dev Writes a bytes20 to the buffer. Resizes if doing so would exceed the
   *      capacity of the buffer.
   * @param buf The buffer to append to.
   * @param off The offset to write at.
   * @param data The data to append.
   * @return The original buffer, for chaining.
   */
  function writeBytes20(
    buffer memory buf,
    uint256 off,
    bytes20 data
  ) internal pure returns (buffer memory) {
    return write(buf, off, bytes32(data), 20);
  }

  /**
   * @dev Appends a bytes20 to the buffer. Resizes if doing so would exceed
   *      the capacity of the buffer.
   * @param buf The buffer to append to.
   * @param data The data to append.
   * @return The original buffer, for chhaining.
   */
  function appendBytes20(buffer memory buf, bytes20 data) internal pure returns (buffer memory) {
    return write(buf, buf.buf.length, bytes32(data), 20);
  }

  /**
   * @dev Appends a bytes32 to the buffer. Resizes if doing so would exceed
   *      the capacity of the buffer.
   * @param buf The buffer to append to.
   * @param data The data to append.
   * @return The original buffer, for chaining.
   */
  function appendBytes32(buffer memory buf, bytes32 data) internal pure returns (buffer memory) {
    return write(buf, buf.buf.length, data, 32);
  }

  /**
   * @dev Writes an integer to the buffer. Resizes if doing so would exceed
   *      the capacity of the buffer.
   * @param buf The buffer to append to.
   * @param off The offset to write at.
   * @param data The data to append.
   * @param len The number of bytes to write (right-aligned).
   * @return The original buffer, for chaining.
   */
  function writeInt(
    buffer memory buf,
    uint256 off,
    uint256 data,
    uint256 len
  ) private pure returns (buffer memory) {
    if (len + off > buf.capacity) {
      resize(buf, (len + off) * 2);
    }

    uint256 mask = (256**len) - 1;
    assembly {
      // Memory address of the buffer data
      let bufptr := mload(buf)
      // Address = buffer address + off + sizeof(buffer length) + len
      let dest := add(add(bufptr, off), len)
      mstore(dest, or(and(mload(dest), not(mask)), data))
      // Update buffer length if we extended it
      if gt(add(off, len), mload(bufptr)) {
        mstore(bufptr, add(off, len))
      }
    }
    return buf;
  }

  /**
   * @dev Appends a byte to the end of the buffer. Resizes if doing so would
   * exceed the capacity of the buffer.
   * @param buf The buffer to append to.
   * @param data The data to append.
   * @return The original buffer.
   */
  function appendInt(
    buffer memory buf,
    uint256 data,
    uint256 len
  ) internal pure returns (buffer memory) {
    return writeInt(buf, buf.buf.length, data, len);
  }
}

library CBORChainlink {
  using BufferChainlink for BufferChainlink.buffer;

  uint8 private constant MAJOR_TYPE_INT = 0;
  uint8 private constant MAJOR_TYPE_NEGATIVE_INT = 1;
  uint8 private constant MAJOR_TYPE_BYTES = 2;
  uint8 private constant MAJOR_TYPE_STRING = 3;
  uint8 private constant MAJOR_TYPE_ARRAY = 4;
  uint8 private constant MAJOR_TYPE_MAP = 5;
  uint8 private constant MAJOR_TYPE_TAG = 6;
  uint8 private constant MAJOR_TYPE_CONTENT_FREE = 7;

  uint8 private constant TAG_TYPE_BIGNUM = 2;
  uint8 private constant TAG_TYPE_NEGATIVE_BIGNUM = 3;

  function encodeFixedNumeric(BufferChainlink.buffer memory buf, uint8 major, uint64 value) private pure {
    if(value <= 23) {
      buf.appendUint8(uint8((major << 5) | value));
    } else if (value <= 0xFF) {
      buf.appendUint8(uint8((major << 5) | 24));
      buf.appendInt(value, 1);
    } else if (value <= 0xFFFF) {
      buf.appendUint8(uint8((major << 5) | 25));
      buf.appendInt(value, 2);
    } else if (value <= 0xFFFFFFFF) {
      buf.appendUint8(uint8((major << 5) | 26));
      buf.appendInt(value, 4);
    } else {
      buf.appendUint8(uint8((major << 5) | 27));
      buf.appendInt(value, 8);
    }
  }

  function encodeIndefiniteLengthType(BufferChainlink.buffer memory buf, uint8 major) private pure {
    buf.appendUint8(uint8((major << 5) | 31));
  }

  function encodeUInt(BufferChainlink.buffer memory buf, uint value) internal pure {
    if(value > 0xFFFFFFFFFFFFFFFF) {
      encodeBigNum(buf, value);
    } else {
      encodeFixedNumeric(buf, MAJOR_TYPE_INT, uint64(value));
    }
  }

  function encodeInt(BufferChainlink.buffer memory buf, int value) internal pure {
    if(value < -0x10000000000000000) {
      encodeSignedBigNum(buf, value);
    } else if(value > 0xFFFFFFFFFFFFFFFF) {
      encodeBigNum(buf, uint(value));
    } else if(value >= 0) {
      encodeFixedNumeric(buf, MAJOR_TYPE_INT, uint64(uint256(value)));
    } else {
      encodeFixedNumeric(buf, MAJOR_TYPE_NEGATIVE_INT, uint64(uint256(-1 - value)));
    }
  }

  function encodeBytes(BufferChainlink.buffer memory buf, bytes memory value) internal pure {
    encodeFixedNumeric(buf, MAJOR_TYPE_BYTES, uint64(value.length));
    buf.append(value);
  }

  function encodeBigNum(BufferChainlink.buffer memory buf, uint value) internal pure {
    buf.appendUint8(uint8((MAJOR_TYPE_TAG << 5) | TAG_TYPE_BIGNUM));
    encodeBytes(buf, abi.encode(value));
  }

  function encodeSignedBigNum(BufferChainlink.buffer memory buf, int input) internal pure {
    buf.appendUint8(uint8((MAJOR_TYPE_TAG << 5) | TAG_TYPE_NEGATIVE_BIGNUM));
    encodeBytes(buf, abi.encode(uint256(-1 - input)));
  }

  function encodeString(BufferChainlink.buffer memory buf, string memory value) internal pure {
    encodeFixedNumeric(buf, MAJOR_TYPE_STRING, uint64(bytes(value).length));
    buf.append(bytes(value));
  }

  function startArray(BufferChainlink.buffer memory buf) internal pure {
    encodeIndefiniteLengthType(buf, MAJOR_TYPE_ARRAY);
  }

  function startMap(BufferChainlink.buffer memory buf) internal pure {
    encodeIndefiniteLengthType(buf, MAJOR_TYPE_MAP);
  }

  function endSequence(BufferChainlink.buffer memory buf) internal pure {
    encodeIndefiniteLengthType(buf, MAJOR_TYPE_CONTENT_FREE);
  }
}

/**
 * @title Library for common Chainlink functions
 * @dev Uses imported CBOR library for encoding to buffer
 */
library Chainlink {
  // solhint-disable-next-line chainlink-solidity/all-caps-constant-storage-variables
  uint256 internal constant defaultBufferSize = 256;

  using CBORChainlink for BufferChainlink.buffer;

  struct Request {
    bytes32 id;
    address callbackAddress;
    bytes4 callbackFunctionId;
    uint256 nonce;
    BufferChainlink.buffer buf;
  }

  /**
   * @notice Initializes a Chainlink request
   * @dev Sets the ID, callback address, and callback function signature on the request
   * @param self The uninitialized request
   * @param jobId The Job Specification ID
   * @param callbackAddr The callback address
   * @param callbackFunc The callback function signature
   * @return The initialized request
   */
  function _initialize(
    Request memory self,
    bytes32 jobId,
    address callbackAddr,
    bytes4 callbackFunc
  ) internal pure returns (Chainlink.Request memory) {
    BufferChainlink.init(self.buf, defaultBufferSize);
    self.id = jobId;
    self.callbackAddress = callbackAddr;
    self.callbackFunctionId = callbackFunc;
    return self;
  }

  /**
   * @notice Sets the data for the buffer without encoding CBOR on-chain
   * @dev CBOR can be closed with curly-brackets {} or they can be left off
   * @param self The initialized request
   * @param data The CBOR data
   */
  function _setBuffer(Request memory self, bytes memory data) internal pure {
    BufferChainlink.init(self.buf, data.length);
    BufferChainlink.append(self.buf, data);
  }

  /**
   * @notice Adds a string value to the request with a given key name
   * @param self The initialized request
   * @param key The name of the key
   * @param value The string value to add
   */
  function _add(Request memory self, string memory key, string memory value) internal pure {
    self.buf.encodeString(key);
    self.buf.encodeString(value);
  }

  /**
   * @notice Adds a bytes value to the request with a given key name
   * @param self The initialized request
   * @param key The name of the key
   * @param value The bytes value to add
   */
  function _addBytes(Request memory self, string memory key, bytes memory value) internal pure {
    self.buf.encodeString(key);
    self.buf.encodeBytes(value);
  }

  /**
   * @notice Adds a int256 value to the request with a given key name
   * @param self The initialized request
   * @param key The name of the key
   * @param value The int256 value to add
   */
  function _addInt(Request memory self, string memory key, int256 value) internal pure {
    self.buf.encodeString(key);
    self.buf.encodeInt(value);
  }

  /**
   * @notice Adds a uint256 value to the request with a given key name
   * @param self The initialized request
   * @param key The name of the key
   * @param value The uint256 value to add
   */
  function _addUint(Request memory self, string memory key, uint256 value) internal pure {
    self.buf.encodeString(key);
    self.buf.encodeUInt(value);
  }

  /**
   * @notice Adds an array of strings to the request with a given key name
   * @param self The initialized request
   * @param key The name of the key
   * @param values The array of string values to add
   */
  function _addStringArray(Request memory self, string memory key, string[] memory values) internal pure {
    self.buf.encodeString(key);
    self.buf.startArray();
    for (uint256 i = 0; i < values.length; i++) {
      self.buf.encodeString(values[i]);
    }
    self.buf.endSequence();
  }
}

// solhint-disable-next-line interface-starts-with-i
interface ChainlinkRequestInterface {
  function oracleRequest(
    address sender,
    uint256 requestPrice,
    bytes32 serviceAgreementID,
    address callbackAddress,
    bytes4 callbackFunctionId,
    uint256 nonce,
    uint256 dataVersion,
    bytes calldata data
  ) external;

  function cancelOracleRequest(
    bytes32 requestId,
    uint256 payment,
    bytes4 callbackFunctionId,
    uint256 expiration
  ) external;
}

// solhint-disable-next-line interface-starts-with-i
interface ENSInterface {
  // Logged when the owner of a node assigns a new owner to a subnode.
  event NewOwner(bytes32 indexed node, bytes32 indexed label, address owner);

  // Logged when the owner of a node transfers ownership to a new account.
  event Transfer(bytes32 indexed node, address owner);

  // Logged when the resolver for a node changes.
  event NewResolver(bytes32 indexed node, address resolver);

  // Logged when the TTL of a node changes
  event NewTTL(bytes32 indexed node, uint64 ttl);

  function setSubnodeOwner(bytes32 node, bytes32 label, address owner) external;

  function setResolver(bytes32 node, address resolver) external;

  function setOwner(bytes32 node, address owner) external;

  function setTTL(bytes32 node, uint64 ttl) external;

  function owner(bytes32 node) external view returns (address);

  function resolver(bytes32 node) external view returns (address);

  function ttl(bytes32 node) external view returns (uint64);
}

// solhint-disable-next-line interface-starts-with-i
interface OracleInterface {
  function fulfillOracleRequest(
    bytes32 requestId,
    uint256 payment,
    address callbackAddress,
    bytes4 callbackFunctionId,
    uint256 expiration,
    bytes32 data
  ) external returns (bool);

  function withdraw(address recipient, uint256 amount) external;

  function withdrawable() external view returns (uint256);
}

// solhint-disable-next-line interface-starts-with-i
interface OperatorInterface is OracleInterface, ChainlinkRequestInterface {
  function operatorRequest(
    address sender,
    uint256 payment,
    bytes32 specId,
    bytes4 callbackFunctionId,
    uint256 nonce,
    uint256 dataVersion,
    bytes calldata data
  ) external;

  function fulfillOracleRequest2(
    bytes32 requestId,
    uint256 payment,
    address callbackAddress,
    bytes4 callbackFunctionId,
    uint256 expiration,
    bytes calldata data
  ) external returns (bool);

  function ownerTransferAndCall(address to, uint256 value, bytes calldata data) external returns (bool success);

  function distributeFunds(address payable[] calldata receivers, uint256[] calldata amounts) external payable;
}

// solhint-disable-next-line interface-starts-with-i
interface PointerInterface {
  function getAddress() external view returns (address);
}

// solhint-disable-next-line interface-starts-with-i
interface LinkTokenInterface {
  function allowance(address owner, address spender) external view returns (uint256 remaining);

  function approve(address spender, uint256 value) external returns (bool success);

  function balanceOf(address owner) external view returns (uint256 balance);

  function decimals() external view returns (uint8 decimalPlaces);

  function decreaseApproval(address spender, uint256 addedValue) external returns (bool success);

  function increaseApproval(address spender, uint256 subtractedValue) external;

  function name() external view returns (string memory tokenName);

  function symbol() external view returns (string memory tokenSymbol);

  function totalSupply() external view returns (uint256 totalTokensIssued);

  function transfer(address to, uint256 value) external returns (bool success);

  function transferAndCall(address to, uint256 value, bytes calldata data) external returns (bool success);

  function transferFrom(address from, address to, uint256 value) external returns (bool success);
}

abstract contract ENSResolver {
  function addr(bytes32 node) public view virtual returns (address);
}

/**
 * @title The ChainlinkClient contract
 * @notice Contract writers can inherit this contract in order to create requests for the
 * Chainlink network
 */
// solhint-disable gas-custom-errors
abstract contract ChainlinkClient {
  using Chainlink for Chainlink.Request;

  uint256 internal constant LINK_DIVISIBILITY = 10 ** 18;
  uint256 private constant AMOUNT_OVERRIDE = 0;
  address private constant SENDER_OVERRIDE = address(0);
  uint256 private constant ORACLE_ARGS_VERSION = 1;
  uint256 private constant OPERATOR_ARGS_VERSION = 2;
  bytes32 private constant ENS_TOKEN_SUBNAME = keccak256("link");
  bytes32 private constant ENS_ORACLE_SUBNAME = keccak256("oracle");
  address private constant LINK_TOKEN_POINTER = 0xC89bD4E1632D3A43CB03AAAd5262cbe4038Bc571;

  ENSInterface private s_ens;
  bytes32 private s_ensNode;
  LinkTokenInterface private s_link;
  OperatorInterface private s_oracle;
  uint256 private s_requestCount = 1;
  mapping(bytes32 => address) private s_pendingRequests;

  event ChainlinkRequested(bytes32 indexed id);
  event ChainlinkFulfilled(bytes32 indexed id);
  event ChainlinkCancelled(bytes32 indexed id);

  /**
   * @notice Creates a request that can hold additional parameters
   * @param specId The Job Specification ID that the request will be created for
   * @param callbackAddr address to operate the callback on
   * @param callbackFunctionSignature function signature to use for the callback
   * @return A Chainlink Request struct in memory
   */
  function _buildChainlinkRequest(
    bytes32 specId,
    address callbackAddr,
    bytes4 callbackFunctionSignature
  ) internal pure returns (Chainlink.Request memory) {
    Chainlink.Request memory req;
    return req._initialize(specId, callbackAddr, callbackFunctionSignature);
  }

  /**
   * @notice Creates a request that can hold additional parameters
   * @param specId The Job Specification ID that the request will be created for
   * @param callbackFunctionSignature function signature to use for the callback
   * @return A Chainlink Request struct in memory
   */
  function _buildOperatorRequest(
    bytes32 specId,
    bytes4 callbackFunctionSignature
  ) internal view returns (Chainlink.Request memory) {
    Chainlink.Request memory req;
    return req._initialize(specId, address(this), callbackFunctionSignature);
  }

  /**
   * @notice Creates a Chainlink request to the stored oracle address
   * @dev Calls `chainlinkRequestTo` with the stored oracle address
   * @param req The initialized Chainlink Request
   * @param payment The amount of LINK to send for the request
   * @return requestId The request ID
   */
  function _sendChainlinkRequest(Chainlink.Request memory req, uint256 payment) internal returns (bytes32) {
    return _sendChainlinkRequestTo(address(s_oracle), req, payment);
  }

  /**
   * @notice Creates a Chainlink request to the specified oracle address
   * @dev Generates and stores a request ID, increments the local nonce, and uses `transferAndCall` to
   * send LINK which creates a request on the target oracle contract.
   * Emits ChainlinkRequested event.
   * @param oracleAddress The address of the oracle for the request
   * @param req The initialized Chainlink Request
   * @param payment The amount of LINK to send for the request
   * @return requestId The request ID
   */
  function _sendChainlinkRequestTo(
    address oracleAddress,
    Chainlink.Request memory req,
    uint256 payment
  ) internal returns (bytes32 requestId) {
    uint256 nonce = s_requestCount;
    s_requestCount = nonce + 1;
    bytes memory encodedRequest = abi.encodeWithSelector(
      ChainlinkRequestInterface.oracleRequest.selector,
      SENDER_OVERRIDE, // Sender value - overridden by onTokenTransfer by the requesting contract's address
      AMOUNT_OVERRIDE, // Amount value - overridden by onTokenTransfer by the actual amount of LINK sent
      req.id,
      address(this),
      req.callbackFunctionId,
      nonce,
      ORACLE_ARGS_VERSION,
      req.buf.buf
    );
    return _rawRequest(oracleAddress, nonce, payment, encodedRequest);
  }

  /**
   * @notice Creates a Chainlink request to the stored oracle address
   * @dev This function supports multi-word response
   * @dev Calls `sendOperatorRequestTo` with the stored oracle address
   * @param req The initialized Chainlink Request
   * @param payment The amount of LINK to send for the request
   * @return requestId The request ID
   */
  function _sendOperatorRequest(Chainlink.Request memory req, uint256 payment) internal returns (bytes32) {
    return _sendOperatorRequestTo(address(s_oracle), req, payment);
  }

  /**
   * @notice Creates a Chainlink request to the specified oracle address
   * @dev This function supports multi-word response
   * @dev Generates and stores a request ID, increments the local nonce, and uses `transferAndCall` to
   * send LINK which creates a request on the target oracle contract.
   * Emits ChainlinkRequested event.
   * @param oracleAddress The address of the oracle for the request
   * @param req The initialized Chainlink Request
   * @param payment The amount of LINK to send for the request
   * @return requestId The request ID
   */
  function _sendOperatorRequestTo(
    address oracleAddress,
    Chainlink.Request memory req,
    uint256 payment
  ) internal returns (bytes32 requestId) {
    uint256 nonce = s_requestCount;
    s_requestCount = nonce + 1;
    bytes memory encodedRequest = abi.encodeWithSelector(
      OperatorInterface.operatorRequest.selector,
      SENDER_OVERRIDE, // Sender value - overridden by onTokenTransfer by the requesting contract's address
      AMOUNT_OVERRIDE, // Amount value - overridden by onTokenTransfer by the actual amount of LINK sent
      req.id,
      req.callbackFunctionId,
      nonce,
      OPERATOR_ARGS_VERSION,
      req.buf.buf
    );
    return _rawRequest(oracleAddress, nonce, payment, encodedRequest);
  }

  /**
   * @notice Make a request to an oracle
   * @param oracleAddress The address of the oracle for the request
   * @param nonce used to generate the request ID
   * @param payment The amount of LINK to send for the request
   * @param encodedRequest data encoded for request type specific format
   * @return requestId The request ID
   */
  function _rawRequest(
    address oracleAddress,
    uint256 nonce,
    uint256 payment,
    bytes memory encodedRequest
  ) private returns (bytes32 requestId) {
    requestId = keccak256(abi.encodePacked(this, nonce));
    s_pendingRequests[requestId] = oracleAddress;
    emit ChainlinkRequested(requestId);
    require(s_link.transferAndCall(oracleAddress, payment, encodedRequest), "unable to transferAndCall to oracle");
    return requestId;
  }

  /**
   * @notice Allows a request to be cancelled if it has not been fulfilled
   * @dev Requires keeping track of the expiration value emitted from the oracle contract.
   * Deletes the request from the `pendingRequests` mapping.
   * Emits ChainlinkCancelled event.
   * @param requestId The request ID
   * @param payment The amount of LINK sent for the request
   * @param callbackFunc The callback function specified for the request
   * @param expiration The time of the expiration for the request
   */
  function _cancelChainlinkRequest(
    bytes32 requestId,
    uint256 payment,
    bytes4 callbackFunc,
    uint256 expiration
  ) internal {
    OperatorInterface requested = OperatorInterface(s_pendingRequests[requestId]);
    delete s_pendingRequests[requestId];
    emit ChainlinkCancelled(requestId);
    requested.cancelOracleRequest(requestId, payment, callbackFunc, expiration);
  }

  /**
   * @notice the next request count to be used in generating a nonce
   * @dev starts at 1 in order to ensure consistent gas cost
   * @return returns the next request count to be used in a nonce
   */
  function _getNextRequestCount() internal view returns (uint256) {
    return s_requestCount;
  }

  /**
   * @notice Sets the stored oracle address
   * @param oracleAddress The address of the oracle contract
   */
  function _setChainlinkOracle(address oracleAddress) internal {
    s_oracle = OperatorInterface(oracleAddress);
  }

  /**
   * @notice Sets the LINK token address
   * @param linkAddress The address of the LINK token contract
   */
  function _setChainlinkToken(address linkAddress) internal {
    s_link = LinkTokenInterface(linkAddress);
  }

  /**
   * @notice Sets the Chainlink token address for the public
   * network as given by the Pointer contract
   */
  function _setPublicChainlinkToken() internal {
    _setChainlinkToken(PointerInterface(LINK_TOKEN_POINTER).getAddress());
  }

  /**
   * @notice Retrieves the stored address of the LINK token
   * @return The address of the LINK token
   */
  function _chainlinkTokenAddress() internal view returns (address) {
    return address(s_link);
  }

  /**
   * @notice Retrieves the stored address of the oracle contract
   * @return The address of the oracle contract
   */
  function _chainlinkOracleAddress() internal view returns (address) {
    return address(s_oracle);
  }

  /**
   * @notice Allows for a request which was created on another contract to be fulfilled
   * on this contract
   * @param oracleAddress The address of the oracle contract that will fulfill the request
   * @param requestId The request ID used for the response
   */
  function _addChainlinkExternalRequest(
    address oracleAddress,
    bytes32 requestId
  ) internal notPendingRequest(requestId) {
    s_pendingRequests[requestId] = oracleAddress;
  }

  /**
   * @notice Ensures that the fulfillment is valid for this contract
   * @dev Use if the contract developer prefers methods instead of modifiers for validation
   * @param requestId The request ID for fulfillment
   */
  function _validateChainlinkCallback(
    bytes32 requestId
  )
    internal
    recordChainlinkFulfillment(requestId) // solhint-disable-next-line no-empty-blocks
  {}

  /**
   * @dev Reverts if the sender is not the oracle of the request.
   * Emits ChainlinkFulfilled event.
   * @param requestId The request ID for fulfillment
   */
  modifier recordChainlinkFulfillment(bytes32 requestId) {
    require(msg.sender == s_pendingRequests[requestId], "Source must be the oracle of the request");
    delete s_pendingRequests[requestId];
    emit ChainlinkFulfilled(requestId);
    _;
  }

  /**
   * @dev Reverts if the request is already pending
   * @param requestId The request ID for fulfillment
   */
  modifier notPendingRequest(bytes32 requestId) {
    require(s_pendingRequests[requestId] == address(0), "Request is already pending");
    _;
  }
}

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    /**
     * @dev Muldiv operation overflow.
     */
    error MathOverflowedMulDiv();

    enum Rounding {
        Floor, // Toward negative infinity
        Ceil, // Toward positive infinity
        Trunc, // Toward zero
        Expand // Away from zero
    }

    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, with an overflow flag.
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds towards infinity instead
     * of rounding towards zero.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        if (b == 0) {
            // Guarantee the same behavior as in a regular Solidity division.
            return a / b;
        }

        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a == 0 ? 0 : (a - 1) / b + 1;
    }

    /**
     * @notice Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or
     * denominator == 0.
     * @dev Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv) with further edits by
     * Uniswap Labs also under MIT license.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
            // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2^256 + prod0.
            uint256 prod0 = x * y; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(x, y, not(0))
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Handle non-overflow cases, 256 by 256 division.
            if (prod1 == 0) {
                // Solidity will revert if denominator == 0, unlike the div opcode on its own.
                // The surrounding unchecked block does not change this fact.
                // See https://docs.soliditylang.org/en/latest/control-structures.html#checked-or-unchecked-arithmetic.
                return prod0 / denominator;
            }

            // Make sure the result is less than 2^256. Also prevents denominator == 0.
            if (denominator <= prod1) {
                revert MathOverflowedMulDiv();
            }

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [prod1 prod0].
            uint256 remainder;
            assembly {
                // Compute remainder using mulmod.
                remainder := mulmod(x, y, denominator)

                // Subtract 256 bit number from 512 bit number.
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator.
            // Always >= 1. See https://cs.stackexchange.com/q/138556/92363.

            uint256 twos = denominator & (0 - denominator);
            assembly {
                // Divide denominator by twos.
                denominator := div(denominator, twos)

                // Divide [prod1 prod0] by twos.
                prod0 := div(prod0, twos)

                // Flip twos such that it is 2^256 / twos. If twos is zero, then it becomes one.
                twos := add(div(sub(0, twos), twos), 1)
            }

            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * twos;

            // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
            // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv = 1 mod 2^4.
            uint256 inverse = (3 * denominator) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also
            // works in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2^8
            inverse *= 2 - denominator * inverse; // inverse mod 2^16
            inverse *= 2 - denominator * inverse; // inverse mod 2^32
            inverse *= 2 - denominator * inverse; // inverse mod 2^64
            inverse *= 2 - denominator * inverse; // inverse mod 2^128
            inverse *= 2 - denominator * inverse; // inverse mod 2^256

            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
            // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inverse;
            return result;
        }
    }

    /**
     * @notice Calculates x * y / denominator with full precision, following the selected rounding direction.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator, Rounding rounding) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (unsignedRoundsUp(rounding) && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded
     * towards zero.
     *
     * Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        // For our first guess, we get the biggest power of 2 which is smaller than the square root of the target.
        //
        // We know that the "msb" (most significant bit) of our target number `a` is a power of 2 such that we have
        // `msb(a) <= a < 2*msb(a)`. This value can be written `msb(a)=2**k` with `k=log2(a)`.
        //
        // This can be rewritten `2**log2(a) <= a < 2**(log2(a) + 1)`
        // → `sqrt(2**k) <= sqrt(a) < sqrt(2**(k+1))`
        // → `2**(k/2) <= sqrt(a) < 2**((k+1)/2) <= 2**(k/2 + 1)`
        //
        // Consequently, `2**(log2(a) / 2)` is a good first approximation of `sqrt(a)` with at least 1 correct bit.
        uint256 result = 1 << (log2(a) >> 1);

        // At this point `result` is an estimation with one bit of precision. We know the true value is a uint128,
        // since it is the square root of a uint256. Newton's method converges quadratically (precision doubles at
        // every iteration). We thus need at most 7 iteration to turn our partial result with one bit of precision
        // into the expected uint128 result.
        unchecked {
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            return min(result, a / result);
        }
    }

    /**
     * @notice Calculates sqrt(a), following the selected rounding direction.
     */
    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = sqrt(a);
            return result + (unsignedRoundsUp(rounding) && result * result < a ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 2 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     */
    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 128;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 64;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 32;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 16;
            }
            if (value >> 8 > 0) {
                value >>= 8;
                result += 8;
            }
            if (value >> 4 > 0) {
                value >>= 4;
                result += 4;
            }
            if (value >> 2 > 0) {
                value >>= 2;
                result += 2;
            }
            if (value >> 1 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 2, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log2(value);
            return result + (unsignedRoundsUp(rounding) && 1 << result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 10 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     */
    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10 ** 64) {
                value /= 10 ** 64;
                result += 64;
            }
            if (value >= 10 ** 32) {
                value /= 10 ** 32;
                result += 32;
            }
            if (value >= 10 ** 16) {
                value /= 10 ** 16;
                result += 16;
            }
            if (value >= 10 ** 8) {
                value /= 10 ** 8;
                result += 8;
            }
            if (value >= 10 ** 4) {
                value /= 10 ** 4;
                result += 4;
            }
            if (value >= 10 ** 2) {
                value /= 10 ** 2;
                result += 2;
            }
            if (value >= 10 ** 1) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log10(value);
            return result + (unsignedRoundsUp(rounding) && 10 ** result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 256 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     *
     * Adding one to the result gives the number of pairs of hex symbols needed to represent `value` as a hex string.
     */
    function log256(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 16;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 8;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 4;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 2;
            }
            if (value >> 8 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 256, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + (unsignedRoundsUp(rounding) && 1 << (result << 3) < value ? 1 : 0);
        }
    }

    /**
     * @dev Returns whether a provided rounding mode is considered rounding up for unsigned integers.
     */
    function unsignedRoundsUp(Rounding rounding) internal pure returns (bool) {
        return uint8(rounding) % 2 == 1;
    }
}


/**
 * @dev Standard signed math utilities missing in the Solidity language.
 */
library SignedMath {
    /**
     * @dev Returns the largest of two signed numbers.
     */
    function max(int256 a, int256 b) internal pure returns (int256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two signed numbers.
     */
    function min(int256 a, int256 b) internal pure returns (int256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two signed numbers without overflow.
     * The result is rounded towards zero.
     */
    function average(int256 a, int256 b) internal pure returns (int256) {
        // Formula from the book "Hacker's Delight"
        int256 x = (a & b) + ((a ^ b) >> 1);
        return x + (int256(uint256(x) >> 255) & (a ^ b));
    }

    /**
     * @dev Returns the absolute unsigned value of a signed value.
     */
    function abs(int256 n) internal pure returns (uint256) {
        unchecked {
            // must be unchecked in order to support `n = type(int256).min`
            return uint256(n >= 0 ? n : -n);
        }
    }
}

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant HEX_DIGITS = "0123456789abcdef";
    uint8 private constant ADDRESS_LENGTH = 20;

    /**
     * @dev The `value` string doesn't fit in the specified `length`.
     */
    error StringsInsufficientHexLength(uint256 value, uint256 length);

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = Math.log10(value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;
            /// @solidity memory-safe-assembly
            assembly {
                ptr := add(buffer, add(32, length))
            }
            while (true) {
                ptr--;
                /// @solidity memory-safe-assembly
                assembly {
                    mstore8(ptr, byte(mod(value, 10), HEX_DIGITS))
                }
                value /= 10;
                if (value == 0) break;
            }
            return buffer;
        }
    }

    /**
     * @dev Converts a `int256` to its ASCII `string` decimal representation.
     */
    function toStringSigned(int256 value) internal pure returns (string memory) {
        return string.concat(value < 0 ? "-" : "", toString(SignedMath.abs(value)));
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        unchecked {
            return toHexString(value, Math.log256(value) + 1);
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        uint256 localValue = value;
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = HEX_DIGITS[localValue & 0xf];
            localValue >>= 4;
        }
        if (localValue != 0) {
            revert StringsInsufficientHexLength(value, length);
        }
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal
     * representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), ADDRESS_LENGTH);
    }

    /**
     * @dev Returns true if the two strings are equal.
     */
    function equal(string memory a, string memory b) internal pure returns (bool) {
        return bytes(a).length == bytes(b).length && keccak256(bytes(a)) == keccak256(bytes(b));
    }
}

/**
 * @member index the index of the log in the block. 0 for the first log
 * @member timestamp the timestamp of the block containing the log
 * @member txHash the hash of the transaction containing the log
 * @member blockNumber the number of the block containing the log
 * @member blockHash the hash of the block containing the log
 * @member source the address of the contract that emitted the log
 * @member topics the indexed topics of the log
 * @member data the data of the log
 */
struct Log {
  uint256 index;
  uint256 timestamp;
  bytes32 txHash;
  uint256 blockNumber;
  bytes32 blockHash;
  address source;
  bytes32[] topics;
  bytes data;
}

interface ILogAutomation {
  /**
   * @notice method that is simulated by the keepers to see if any work actually
   * needs to be performed. This method does does not actually need to be
   * executable, and since it is only ever simulated it can consume lots of gas.
   * @dev To ensure that it is never called, you may want to add the
   * cannotExecute modifier from KeeperBase to your implementation of this
   * method.
   * @param log the raw log data matching the filter that this contract has
   * registered as a trigger
   * @param checkData user-specified extra data to provide context to this upkeep
   * @return upkeepNeeded boolean to indicate whether the keeper should call
   * performUpkeep or not.
   * @return performData bytes that the keeper should call performUpkeep with, if
   * upkeep is needed. If you would like to encode data to decode later, try
   * `abi.encode`.
   */
  function checkLog(
    Log calldata log,
    bytes memory checkData
  ) external returns (bool upkeepNeeded, bytes memory performData);

  /**
   * @notice method that is actually executed by the keepers, via the registry.
   * The data returned by the checkUpkeep simulation will be passed into
   * this method to actually be executed.
   * @dev The input to this method should not be trusted, and the caller of the
   * method should not even be restricted to any single registry. Anyone should
   * be able call it, and the input should be validated, there is no guarantee
   * that the data passed in is the performData returned from checkUpkeep. This
   * could happen due to malicious keepers, racing keepers, or simply a state
   * change while the performUpkeep transaction is waiting for confirmation.
   * Always validate the data passed in.
   * @param performData is the data which was passed back from the checkData
   * simulation. If it is encoded, it can easily be decoded into other types by
   * calling `abi.decode`. This data should not be trusted, and should be
   * validated against the contract's current state.
   */
  function performUpkeep(bytes calldata performData) external;
}


// solhint-disable-next-line interface-starts-with-i
interface AggregatorV3Interface {
  function decimals() external view returns (uint8);

  function description() external view returns (string memory);

  function version() external view returns (uint256);

  function getRoundData(
    uint80 _roundId
  ) external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);

  function latestRoundData()
    external
    view
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function mint(address account, uint256 amount) external returns(bool);
    function burn(address account, uint256 amount) external returns (bool);
}

abstract contract Types {
    struct IRS {
        address fixedRatePayer;
        address floatingRatePayer;
        address oracleContractForBenchmark;
        address settlementCurrency;
        uint8 ratesDecimals;
        uint8 dayCountBasis;
        int256 swapRate;
        int256 spread;
        uint256 notionalAmount;
        uint256 settlementFrequency;
        uint256 startingDate;
        uint256 maturityDate;
        uint256[] settlementDates;
    }

    struct MarginRequirement {
        uint256 marginBuffer;
        uint256 terminationFee;
    }
    
    struct IRSReceipt {
        address from;
        address to;
        uint256 netAmount;
        uint256 timestamp;
        uint256 fixedRatePayment;
        uint256 floatingRatePayment;
    }
}

/**
* @notice This token contract allows tokenize Interest Rate Swap cashflows.
*         Approval and Transfer of tokens are allowed only before the IRS contract reaches maturity.
*         This feature prevents tokens to be traded after the contract has matured.
*         When tokens are transferred to an account, the ownership (fixedRatePayer or floatingRatePayer) is also transferred.
*         The contract doesn't support partial transfer of tokens. All the balance must be transferred for the transaction to be successful.
*/
contract IRSToken is IERC20 {
    Types.IRS internal irs;

    modifier onlyBeforeMaturity() {
        require(
            block.timestamp <= irs.maturityDate,
            "IRS contract has reached the Maturity Date"
        );
        _;
    }

    mapping(address => uint256) internal _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 internal _totalSupply;
    uint256 internal _maxSupply;
    uint256 private _burnedSupply;

    string private _name;
    string private _symbol;

    error supplyExceededMaxSupply(uint256 totalSupply_, uint256 maxSupply_);

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function maxSupply() public view returns(uint256) {
        return _maxSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = msg.sender;
        _transfer(owner, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = msg.sender;
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = msg.sender;
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual onlyBeforeMaturity {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance == amount, "ERC20: you must transfer all your balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }

        if(from == irs.fixedRatePayer) {
            irs.fixedRatePayer = to;
        } else if(from == irs.floatingRatePayer) {
            irs.floatingRatePayer = to;
        } else {
            revert("invalid from address");
        }

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    function mint(address account, uint256 amount) public virtual override returns (bool) {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        if (_totalSupply + _burnedSupply > _maxSupply) revert supplyExceededMaxSupply(_totalSupply, _maxSupply);

        unchecked {
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);

        return true;
    }

    function burn(address account, uint256 amount) public virtual override returns (bool) {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            _totalSupply -= amount;
            _burnedSupply += amount;
        }

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);

        return true;
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual onlyBeforeMaturity {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

}

interface IERC7586 {
    //-------------------------- Events --------------------------
    /**
    * @notice MUST be emitted when interest rates are swapped
    * @param _account the recipient account to send the interest difference to. MUST be either the `payer` or the `receiver`
    * @param _amount the interest difference to be transferred
    */
    event Swap(address _account, uint256 _amount);

    /**
    * @notice MUST be emitted when the swap contract is terminated
    * @param _payer the swap payer
    * @param _receiver the swap receiver
    */
    event TerminateSwap(address indexed _payer, address indexed _receiver);

    //-------------------------- Functions --------------------------
    /**
    *  @notice Returns the IRS `payer` account address. The party who agreed to pay fixed interest
    */
    function fixedRatePayer() external view returns(address);

    /**
    *  @notice Returns the IRS `receiver` account address. The party who agreed to pay floating interest
    */
    function floatingRatePayer() external view returns(address);

    /**
    * @notice Returns the number of decimals the swap rate and spread use - e.g. `4` means to divide the rates by `10000`
    *         To express the interest rates in basis points unit, the decimal MUST be equal to `2`. This means rates MUST be divided by `100`
    *         1 basis point = 0.01% = 0.0001
    *         ex: if interest rate = 2.5%, then swapRate() => 250 `basis points`
    */
    function ratesDecimals() external view returns(uint8);

    /**
    *  @notice Returns the fixed interest rate. All rates MUST be multiplied by 10^(ratesDecimals)
    */
    function swapRate() external view returns(int256);

    /**
    *  @notice Returns the floating rate spread, i.e. the fixed part of the floating interest rate. All rates MUST be multiplied by 10^(ratesDecimals)
    *          floatingRate = benchmark + spread
    */
    function spread() external view returns(int256);

    /**
    * @notice Returns the day count basis
    *         For example, 0 can denote actual/actual, 1 can denote actual/360, and so on
    */
    function dayCountBasis() external view returns(uint8);

    /**
    *  @notice Returns the contract address of the settlement currency(Example: USDC contract address).
    *          Returns the zero address if the contracct is settled in FIAT currency like USD
    */
    function settlementCurrency() external view returns(address);

    /**
    *  @notice Returns the notional amount in unit of asset to be transferred when swapping IRS. This amount serves as the basis for calculating the interest payments, and may not be exchanged
    *          Example: If the two parties aggreed to swap interest rates in USDC, then the notional amount may be equal to 1,000,000 USDC 
    */
    function notionalAmount() external view returns(uint256);

    /**
    *  @notice Returns the number of times settlement must be realized in 1 year
    */
    function settlementFrequency() external view returns(uint256);

    /**
    *  @notice Returns an array of settlement dates. Each date MUST be a Unix timestamp like the one returned by block.timestamp
    *          The length of the array returned by this function MUST equal the total number of swaps that should be realized
    *
    *  OPTIONAL
    */
    function settlementDates() external view returns(uint256[] memory);

    /**
    *  @notice Returns the starting date of the swap contract. This is a Unix Timestamp like the one returned by block.timestamp
    */
    function startingDate() external view returns(uint256);

    /**
    *  @notice Returns the maturity date of the swap contract. This is a Unix Timestamp like the one returned by block.timestamp
    */
    function maturityDate() external view returns(uint256);

    /**
    *  @notice Returns the oracle contract address for acceptable reference rates (benchmark), or the zero address when the two parties agreed to set the benchmark manually.
    *          This contract SHOULD be used to fetch real time benchmark rate
    *          Example: Contract address for `CF BIRC`
    *
    *  OPTIONAL. The two parties MAY agree to set the benchmark manually
    */
    function oracleContractForBenchmark() external view returns(address);

    /**
    *  @notice Makes swap calculation and transfers the payment to counterparties
    */
    function swap() external returns(bool);

    /**
    *  @notice Terminates the swap contract before its maturity date. MUST be called by either the `payer`or the `receiver`.
    */
    function terminateSwap() external;
}

abstract contract ERC7586 is IERC7586, IRSToken, ChainlinkClient, ILogAutomation {
    using Chainlink for Chainlink.Request;

    int256 internal referenceRate;
    int256 internal lockedReferenceRate;
    uint256 internal netSettlementAmount;
    uint256 internal terminationAmount;
    uint8 internal transferMode;  // 0 -> transfer from payer account (transferFrom), 1 -> transfer from the contract balance (transfer)
    uint8 internal swapCount;

    address internal receiverParty;
    address internal payerParty;
    address internal terminationReceiver;

    AggregatorV3Interface internal ETHStakingFeed;

    error invalidTransferMode(uint8 _transferMode);

    constructor(
        string memory _irsTokenName,
        string memory _irsTokenSymbol,
        Types.IRS memory _irs,
        address _linkToken,
        address _chainlinkOracle
    ) IRSToken(_irsTokenName, _irsTokenSymbol) {
        irs = _irs;
        ETHStakingFeed = AggregatorV3Interface(_irs.oracleContractForBenchmark);
        _setChainlinkToken(_linkToken);
        _setChainlinkOracle(_chainlinkOracle);

        // one token minted for each settlement cycle per counterparty
        uint256 balance = uint256(_irs.settlementDates.length) * 1 ether;
        _maxSupply = 2 * balance;

        mint(_irs.fixedRatePayer, balance);
        mint(_irs.floatingRatePayer, balance);
    }

    function fixedRatePayer() external view returns(address) {
        return irs.fixedRatePayer;
    }

    function floatingRatePayer() external view returns(address) {
        return irs.floatingRatePayer;
    }

    function ratesDecimals() external view returns(uint8) {
        return irs.ratesDecimals;
    }

    function swapRate() external view returns(int256) {
        return irs.swapRate;
    }

    function spread() external view returns(int256) {
        return irs.spread;
    }

    function dayCountBasis() external view returns(uint8) {
        return irs.dayCountBasis;
    }

    function settlementCurrency() external view returns(address) {
        return irs.settlementCurrency;
    }

    function notionalAmount() external view returns(uint256) {
        return irs.notionalAmount;
    }

    function settlementFrequency() external view returns(uint256) {
        return irs.settlementFrequency;
    }

    function settlementDates() external view returns(uint256[] memory) {
        return irs.settlementDates;
    }

    function startingDate() external view returns(uint256) {
        return irs.startingDate;
    }

    function maturityDate() external view returns(uint256) {
        return irs.maturityDate;
    }

    function oracleContractForBenchmark() external view returns(address) {
        return irs.oracleContractForBenchmark;
    }

    function benchmark() public view returns(int256) {
        return referenceRate;
    }

    //function benchmark() public view returns(int256) {
        //(
        //    /* uint80 roundID */,
        //    int stakingRate,
        //    /*uint startedAt*/,
        //    /*uint timeStamp*/,
        //    /*uint80 answeredInRound*/
        //) = ETHStakingFeed.latestRoundData();

        //return stakingRate;
    //}

    /**
    * @notice Transfer the net settlement amount to the receiver account.
    *         if `transferMode = 0` (enough balance in the payer account), transfer from the payer balance
    *         if `transferMode = 1` (not enough balance in the payer account), transfer from the payer margin buffer
    */
    function swap() public returns(bool) {
        burn(irs.fixedRatePayer, 1 ether);
        burn(irs.floatingRatePayer, 1 ether);

        uint256 settlementAmount = netSettlementAmount * 1 ether / 10_000;

        if (transferMode == 0) {
            IERC20(irs.settlementCurrency).transferFrom(payerParty, receiverParty, settlementAmount);
        } else if (transferMode == 1) {
            IERC20(irs.settlementCurrency).transfer(receiverParty, settlementAmount);
        } else {
            revert invalidTransferMode(transferMode);
        }

        emit Swap(receiverParty, settlementAmount);

        // Prevents the transfer of funds from the outside of ERC6123 contrat
        // This is possible because the receipient of the transferFrom function in ERC20 must not be the zero address
        receiverParty = address(0);

        return true;
    }

    function terminateSwap() public {
        IERC20(irs.settlementCurrency).transfer(terminationReceiver, terminationAmount * 1 ether);
    }

    function getSwapCount() external view returns(uint8) {
        return swapCount;
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
}

abstract contract ERC6123Storage {
    error obseleteFunction();
    error allSettlementsDone();
    error stateMustBeConfirmedOrSettled();
    error invalidTradeID(string _tradeID);
    error invalidPaymentAmount(int256 _amount);
    error invalidPositionValue(int256 _position);
    error nothingToSwap(int256 _fixedRate, int256 _floatingRate);
    error mustBeOtherParty(address _withParty, address _otherParty);
    error cannotInceptWithYourself(address _caller, address _withParty);
    error inconsistentTradeDataOrWrongAddress(address _inceptor, uint256 _dataHash);
    error mustBePayerOrReceiver(address _withParty, address _payer, address _receiver);
    error notEnoughMarginBuffer(uint256 _settlementAmount, uint256 _availableMarginBuffer);

    /*
     * Trade States
     */
    enum TradeState {

        /*
         * State before the trade is incepted.
         */
        Inactive,

        /*
         * Incepted: Trade data submitted by one party. Market data for initial valuation is set.
         */
        Incepted,

        /*
         * Confirmed: Trade data accepted by other party.
         */
        Confirmed,

        /*
         * Valuation Phase: The contract is awaiting a valuation for the next settlement.
         */
        Valuation,

        /*
         * Token-based Transfer is in Progress. Contracts awaits termination of token transfer (allows async transfers).
         */
        InTransfer,

        /*
         * Settlement is Completed.
         */
        Settled,

        /*
         * Termination is in Progress.
         */
        InTermination,
        /*
         * Terminated.
         */
        Terminated,
        /**
        * Has reached Maturity 
        */
       Matured
    }

    modifier onlyWhenTradeInactive() {
        require(
            tradeState == TradeState.Inactive,
            "Trade state is not 'Inactive'."
        ); 
        _;
    }

    modifier onlyWhenTradeIncepted() {
        require(
            tradeState == TradeState.Incepted,
            "Trade state is not 'Incepted'."
        );
        _;
    }

    modifier onlyWhenTradeConfirmed() {
        require(
            tradeState == TradeState.Confirmed,
            "Trade state is not 'Confirmed'." 
        );
        _;
    }

    modifier onlyWhenSettled() {
        require(
            tradeState == TradeState.Settled,
            "Trade state is not 'Settled'."
        );
        _;
    }

    modifier onlyWhenValuation() {
        require(
            tradeState == TradeState.Valuation,
            "Trade state is not 'Valuation'."
        );
        _;
    }

    modifier onlyWhenInTermination () {
        require(
            tradeState == TradeState.InTermination,
            "Trade state is not 'InTermination'."
        );
        _;
    }

    modifier onlyWhenInTransfer() {
        require(
            tradeState == TradeState.InTransfer,
            "Trade state is not 'InTransfer'."
        );
        _;
    }

    modifier onlyWhenConfirmedOrSettled() {
        if(tradeState != TradeState.Confirmed) {
            if(tradeState != TradeState.Settled) {
                revert stateMustBeConfirmedOrSettled();
            }
        }
        _;
    }

    modifier onlyWithinConfirmationTime() {
        require(
            block.timestamp - inceptingTime <= confirmationTime,
            "Confimartion time is over"
        );
        _;
    }

    mapping(address => uint256) internal marginCalls;
    mapping(uint256 => address) internal pendingRequests;
    mapping(address => Types.MarginRequirement) internal marginRequirements;

    TradeState internal tradeState;

    string tradeData;
    string public tradeID;
    string internal referenceRatePath;
    string[] internal referenceRateURLs;
    string[] internal settlementData;

    uint256 internal initialMarginBuffer;
    uint256 internal initialTerminationFee;
    uint256 internal inceptingTime;
    uint256 internal confirmationTime;
    uint256 internal rateMultiplier;
    int256 internal settlementAmount;
    uint256 public numberOfSettlement;

    bytes32 internal jobId;
    uint256 internal fee;

    Types.IRSReceipt[] internal irsReceipts;
}

/*------------------------------------------- DESCRIPTION ---------------------------------------------------------------------------------------*/

/**
 * @title ERC6123 Smart Derivative Contract
 * @dev Interface specification for a Smart Derivative Contract, which specifies the post-trade live cycle of an OTC financial derivative in a completely deterministic way.
 *
 * A Smart Derivative Contract (SDC) is a deterministic settlement protocol which aims is to remove many inefficiencies in (collateralized) financial transactions.
 * Settlement (Delivery versus payment) and Counterparty Credit Risk are removed by construction.
 *
 * Special Case OTC-Derivatives: In case of a collateralized OTC derivative the SDC nets contract-based and collateral flows . As result, the SDC generates a stream of
 * reflecting the settlement of a referenced underlying. The settlement cash flows may be daily (which is the standard frequency in traditional markets)
 * or at higher frequencies.
 * With each settlement flow the change is the (discounting adjusted) net present value of the underlying contract is exchanged and the value of the contract is reset to zero.
 *
 * To automatically process settlement, parties need to provide sufficient initial funding and termination fees at the
 * beginning of each settlement cycle. Through a settlement cycle the margin amounts are locked. Simplified, the contract reverts the classical scheme of
 * 1) underlying valuation, then 2) funding of a margin call to
 * 1) pre-funding of a margin buffer (a token), then 2) settlement.
 *
 * A SDC may automatically terminates the financial contract if there is insufficient pre-funding or if the settlement amount exceeds a
 * prefunded margin balance. Beyond mutual termination is also intended by the function specification.
 *
 * Events and Functionality specify the entire live cycle: TradeInception, TradeConfirmation, TradeTermination, Margin-Account-Mechanics, Valuation and Settlement.
 *
 * The process can be described by time points and time-intervals which are associated with well defined states:
 * <ol>
 *  <li>t < T* (befrore incept).
 *  </li>
 *  <li>
 *      The process runs in cycles. Let i = 0,1,2,... denote the index of the cycle. Within each cycle there are times
 *      T_{i,0}, T_{i,1}, T_{i,2}, T_{i,3} with T_{i,1} = The Activation of the Trade (initial funding provided), T_{i,1} = request valuation from oracle, T_{i,2} = perform settlement on given valuation, T_{i+1,0} = T_{i,3}.
 *  </li>
 *  <li>
 *      Given this time discretization the states are assigned to time points and time intervalls:
 *      <dl>
 *          <dt>Idle</dt>
 *          <dd>Before incept or after terminate</dd>
 *
 *          <dt>Initiation</dt>
 *          <dd>T* < t < T_{0}, where T* is time of incept and T_{0} = T_{0,0}</dd>
 *
 *          <dt>InTransfer (Initiation Phase)</dt>
 *          <dd>T_{i,0} < t < T_{i,1}</dd>
 *
 *          <dt>Settled</dt>
 *          <dd>t = T_{i,1}</dd>
 *
 *          <dt>ValuationAndSettlement</dt>
 *          <dd>T_{i,1} < t < T_{i,2}</dd>
 *
 *          <dt>InTransfer (Settlement Phase)</dt>
 *          <dd>T_{i,2} < t < T_{i,3}</dd>
 *
 *          <dt>Settled</dt>
 *          <dd>t = T_{i,3}</dd>
 *      </dl>
 *  </li>
 * </ol>
 */

interface IERC6123 {

    /*------------------------------------------- EVENTS ---------------------------------------------------------------------------------------*/

    /* Events related to trade inception */

    /**
     * @dev Emitted  when a new trade is incepted from a eligible counterparty
     * @param initiator is the address from which trade was incepted
     * @param withParty is the party the inceptor wants to trade with
     * @param tradeId is the trade ID (e.g. generated internally)
     * @param tradeData a description of the trade specification e.g. in xml format, suggested structure - see assets/eip-6123/doc/sample-tradedata-filestructure.xml
     * @param position is the position the inceptor has in that trade
     * @param paymentAmount is the payment amount which can be positive or negative (viewed from the inceptor)
     * @param initialSettlementData the initial settlement data (e.g. initial market data at which trade was incepted)
     */
    event TradeIncepted(address initiator, address withParty, string tradeId, string tradeData, int position, int256 paymentAmount, string initialSettlementData);

    /**
     * @dev Emitted when an incepted trade is confirmed by the opposite counterparty
     * @param confirmer the confirming party
     * @param tradeId the trade identifier
     */
    event TradeConfirmed(address confirmer, string tradeId);

    /**
     * @dev Emitted when an incepted trade is canceled by the incepting counterparty
     * @param initiator is the address from which trade was canceled
     * @param tradeId the trade identifier
     */
    event TradeCanceled(address initiator, string tradeId);

    /* Events related to activation and termination */

    /**
     * @dev Emitted when a confirmed trade is set to active - e.g. when termination fee amounts are provided
     * @param tradeId the trade identifier of the activated trade
     */
    event TradeActivated(string tradeId);

    /**
     * @dev Emitted when an active trade is terminated
     * @param tradeId the trade identifier of the activated trade
     * @param cause string holding data associated with the termination, e.g. transactionData upon a failed transaction
     */
    event TradeTerminated(string tradeId, string cause);

    /* Events related to the settlement process */

    /**
     * @dev Emitted when a settlement gets requested
     * @param initiator the address of the requesting party
     * @param tradeData holding the stored trade data
     * @param lastSettlementData holding the settlementdata from previous settlement (next settlement will be the increment of next valuation compared to former valuation)
     */
    event SettlementRequested(address initiator, string tradeData, string lastSettlementData);

    /**
     * @dev Emitted when Settlement has been valued and settlement phase is initiated
     * @param initiator the address of the requesting party
     * @param settlementAmount the settlement amount. If settlementAmount > 0 then receivingParty receives this amount from other party. If settlementAmount < 0 then other party receives -settlementAmount from receivingParty.
     * @param settlementData. the tripple (product, previousSettlementData, settlementData) determines the settlementAmount.
     */
    event SettlementEvaluated(address initiator, int256 settlementAmount, string settlementData);

    /**
     * @dev Emitted when settlement process has been finished
     */
    event SettlementTransferred(string transactionData);

    /**
     * @dev Emitted when settlement process has been finished
     */
    event SettlementFailed(string transactionData);

    /* Events related to trade termination */

    /**
     * @dev Emitted when a counterparty proactively requests an early termination of the underlying trade
     * @param initiator the address of the requesting party
     * @param terminationPayment an agreed termination amount (viewed from the requester)
     * @param tradeId the trade identifier which is supposed to be terminated
     * @param terminationTerms termination terms
     */
    event TradeTerminationRequest(address initiator, string tradeId, int256 terminationPayment, string terminationTerms);

    /**
     * @dev Emitted when early termination request is confirmed by the opposite party
     * @param confirmer the party which confirms the trade termination
     * @param tradeId the trade identifier which is supposed to be terminated
     * @param terminationPayment an agreed termination amount (viewed from the confirmer, negative of the value provided by the requester)
     * @param terminationTerms termination terms
     */
    event TradeTerminationConfirmed(address confirmer, string tradeId, int256 terminationPayment, string terminationTerms);

    /**
     * @dev Emitted when a counterparty cancels its requests an early termination of the underlying trade
     * @param initiator the address of the requesting party
     * @param tradeId the trade identifier which is supposed to be terminated
     * @param terminationTerms termination terms
     */
    event TradeTerminationCanceled(address initiator, string tradeId, string terminationTerms);

    /*------------------------------------------- FUNCTIONALITY ---------------------------------------------------------------------------------------*/

    /// Trade Inception

    /**
     * @notice Incepts a trade, stores trade data
     * @dev emits a {TradeIncepted} event
     * @param withParty is the party the inceptor wants to trade with
     * @param tradeData a description of the trade specification e.g. in xml format, suggested structure - see assets/eip-6123/doc/sample-tradedata-filestructure.xml
     * @param position is the position the inceptor has in that trade
     * @param paymentAmount is the payment amount which can be positive or negative (viewed from the inceptor)
     * @param initialSettlementData the initial settlement data (e.g. initial market data at which trade was incepted)
     * @return the tradeId uniquely determining this trade.
     */
    function inceptTrade(address withParty, string memory tradeData, int position, int256 paymentAmount, string memory initialSettlementData) external returns (string memory);

    /**
     * @notice Performs a matching of provided trade data and settlement data of a previous trade inception
     * @dev emits a {TradeConfirmed} event if trade data match and emits a {TradeActivated} if trade becomes active or {TradeTerminated} if not
     * @param withParty is the party the confirmer wants to trade with
     * @param tradeData a description of the trade specification e.g. in xml format, suggested structure - see assets/eip-6123/doc/sample-tradedata-filestructure.xml
     * @param position is the position the confirmer has in that trade (negative of the position the inceptor has in the trade)
     * @param paymentAmount is the payment amount which can be positive or negative (viewed from the confirmer, negative of the inceptor's view)
     * @param initialSettlementData the initial settlement data (e.g. initial market data at which trade was incepted)
     */
     function confirmTrade(address withParty, string memory tradeData, int position, int256 paymentAmount, string memory initialSettlementData) external;

    /**
     * @notice Performs a matching of provided trade data and settlement data of a previous trade inception. Required to be called by inceptor.
     * @dev emits a {TradeCanceled} event if trade data match and msg.sender agrees with the party that incepted the trade.
     * @param withParty is the party the inceptor wants to trade with
     * @param tradeData a description of the trade specification e.g. in xml format, suggested structure - see assets/eip-6123/doc/sample-tradedata-filestructure.xml
     * @param position is the position the inceptor has in that trade
     * @param paymentAmount is the payment amount which can be positive or negative (viewed from the inceptor)
     * @param initialSettlementData the initial settlement data (e.g. initial market data at which trade was incepted)
     */
    function cancelTrade(address withParty, string memory tradeData, int position, int256 paymentAmount, string memory initialSettlementData) external;

    /// Settlement Cycle: Settlement

    /**
     * @notice Called to trigger a (maybe external) valuation of the underlying contract and afterwards the according settlement process
     * @dev emits a {SettlementRequested}
     */
    function initiateSettlement() external;

    /**
     * @notice Called to trigger according settlement on chain-balances callback for initiateSettlement() event handler
     * @dev perform settlement checks, may initiate transfers and emits {SettlementEvaluated}
     * @param settlementAmount the settlement amount. If settlementAmount > 0 then receivingParty receives this amount from other party. If settlementAmount < 0 then other party receives -settlementAmount from receivingParty.
     * @param settlementData. the tripple (product, previousSettlementData, settlementData) determines the settlementAmount.
     */
    function performSettlement(int256 settlementAmount, string memory settlementData) external;


    /**
     * @notice May get called from outside to to finish a transfer (callback). The trade decides on how to proceed based on success flag
     * @param success tells the protocol whether transfer was successful
     * @param transactionData data associtated with the transfer, will be emitted via the events.
     * @dev emit a {SettlementTransferred} or a {SettlementFailed} event. May emit a {TradeTerminated} event.
     */
    function afterTransfer(bool success, string memory transactionData) external;

    /// Trade termination

    /**
     * @notice Called from a counterparty to request a mutual termination
     * @dev emits a {TradeTerminationRequest}
     * @param tradeId the trade identifier which is supposed to be terminated
     * @param terminationPayment an agreed termination amount (viewed from the requester)
     * @param terminationTerms the termination terms to be stored on chain.
     */
    function requestTradeTermination(string memory tradeId, int256 terminationPayment, string memory terminationTerms) external;

    /**
     * @notice Called from a party to confirm an incepted termination, which might trigger a final settlement before trade gets closed
     * @dev emits a {TradeTerminationConfirmed}
     * @param tradeId the trade identifier which is supposed to be terminated
     * @param terminationPayment an agreed termination amount (viewed from the confirmer, negative of the value provided by the requester)
     * @param terminationTerms the termination terms to be stored on chain.
     */
    function confirmTradeTermination(string memory tradeId, int256 terminationPayment, string memory terminationTerms) external;

    /**
     * @notice Called from a party to confirm an incepted termination, which might trigger a final settlement before trade gets closed
     * @dev emits a {TradeTerminationCanceled}
     * @param tradeId the trade identifier which is supposed to be terminated
     * @param terminationPayment an agreed termination amount (viewed from the requester)
     * @param terminationTerms the termination terms
     */
    function cancelTradeTermination(string memory tradeId, int256 terminationPayment, string memory terminationTerms) external;
}

contract ERC6123 is IERC6123, ERC6123Storage, ERC7586 {
    using Chainlink for Chainlink.Request;

    event referenceRateFetched();
    event RequestReferenceRate(bytes32 indexed requestId, int256 referenceRate);

    modifier onlyCounterparty() {
        require(
            msg.sender == irs.fixedRatePayer || msg.sender == irs.floatingRatePayer,
            "You are not a counterparty."
        );
        _;
    }

    constructor (
        string memory _irsTokenName,
        string memory _irsTokenSymbol,
        Types.IRS memory _irs,
        address _linkToken,
        address _chainlinkOracle,
        string memory _jobId,
        uint256 _initialMarginBuffer,
        uint256 _initialTerminationFee,
        uint256 _rateMultiplier
    ) ERC7586(_irsTokenName, _irsTokenSymbol, _irs, _linkToken, _chainlinkOracle) {
        initialMarginBuffer = _initialMarginBuffer;
        initialTerminationFee = _initialTerminationFee;
        confirmationTime = 1 hours;
        rateMultiplier = _rateMultiplier;

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
            _withParty != irs.fixedRatePayer || _withParty != irs.floatingRatePayer,
            "counterparty must be payer or receiver"
        );
        require(_position != 1 || _position != -1, "invalid position");
        if(_paymentAmount == 0) revert invalidPaymentAmount(_paymentAmount);

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

        // The initial margin and the termination fee must be deposited into the contract
        uint256 marginAndFee = initialMarginBuffer + initialTerminationFee;

        require(
            IERC20(irs.settlementCurrency).transfer(address(this), marginAndFee * 1 ether),
            "Failed to to transfer the initial margin + the termination fee"
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
        int256 fixedRate = irs.swapRate;
        int256 floatingRate = benchmark() + irs.spread;
        uint256 fixedPayment = uint256(fixedRate) * irs.notionalAmount / 360;
        uint256 floatingPayment = uint256(floatingRate) * irs.notionalAmount / 360;

        if(fixedRate == floatingRate) {
            revert nothingToSwap(fixedRate, floatingRate);
        } else if(fixedRate > floatingRate) {
            netSettlementAmount = fixedPayment - floatingPayment;
            receiverParty = irs.floatingRatePayer;
            payerParty = irs.fixedRatePayer;

            // Needed just to check the input settlement amount
            require(
                netSettlementAmount * 1 ether / 10_000 == uint256(_settlementAmount),
                "invalid settlement amount"
            );

            // Generates the settlement receipt
            irsReceipts.push(
                Types.IRSReceipt({
                    from: irs.fixedRatePayer,
                    to: receiverParty,
                    netAmount: netSettlementAmount,
                    timestamp: block.timestamp,
                    fixedRatePayment: fixedPayment,
                    floatingRatePayment: floatingPayment
                })
            );
        } else {
            netSettlementAmount = floatingPayment - fixedPayment;
            receiverParty = irs.fixedRatePayer;
            payerParty = irs.floatingRatePayer;

            // Needed just to check the input settlement amount
            require(
                netSettlementAmount * 1 ether / 10_000 == uint256(_settlementAmount),
                "invalid settlement amount"
            );

            // Generates the settlement receipt
            irsReceipts.push(
                Types.IRSReceipt({
                    from: irs.floatingRatePayer,
                    to: receiverParty,
                    netAmount: netSettlementAmount,
                    timestamp: block.timestamp,
                    fixedRatePayment: fixedPayment,
                    floatingRatePayment: floatingPayment
                })
            );
        }

        uint8 _swapCount = swapCount;
        swapCount = _swapCount + 1;

        if(swapCount < irs.settlementDates.length) {
            tradeState = TradeState.Settled;
        } else if (swapCount == irs.settlementDates.length) {
            tradeState = TradeState.Matured;
        } else {
            revert allSettlementsDone();
        }

        _checkBalanceAndSwap(payerParty, netSettlementAmount);

        emit SettlementEvaluated(msg.sender, int256(netSettlementAmount), _settlementData);
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
        requestId = _sendChainlinkRequest(req, fee);
    }

    function fulfill(
        bytes32 _requestId,
        int256 _referenceRate
    ) public recordChainlinkFulfillment(_requestId) {
        emit RequestReferenceRate(_requestId, _referenceRate);

        referenceRate = _referenceRate;

        emit referenceRateFetched();
    }

    function checkLog(
        Log calldata,
        bytes memory
    ) external view returns(bool upkeepNeeded, bytes memory performData) {
        upkeepNeeded = true;
        performData = abi.encode(referenceRate);
    }

    function performUpkeep(bytes calldata performData) external override {
        int256 rate = abi.decode(performData, (int256));

        require(rate == referenceRate, "invalid reference rate");

        performSettlement(settlementAmount, "");
    }

    /** TO BE REMOVED: This function MUST be removed in production */
    function setURLs(string[] memory _urls, string memory _referenceRatePath) external onlyCounterparty {
        referenceRateURLs = _urls;
        referenceRatePath = _referenceRatePath;
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
                swap();
                transferMode = 0;
            }
         } else {
            swap();
         }
    }

    /**---------------------- Internal Private and other view functions ----------------------*/
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
}
