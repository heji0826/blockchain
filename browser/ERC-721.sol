// Klaytn IDE uses solidity 0.4.24, 0.5.6 versions.
pragma solidity ^0.4.2;

interface ERC721 /* is ERC165 */ {

    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);

    event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId);

    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

    function balanceOf(address _owner) public view returns (uint256);

    function ownerOf(uint256 _tokenId) public view returns (address);

    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes data) public;

    function safeTransferFrom(address _from, address _to, uint256 _tokenId) public;

    function transferFrom(address _from, address _to, uint256 _tokenId) public;

    function approve(address _approved, uint256 _tokenId) public;

    function setApprovalForAll(address _operator, bool _approved) public;

    function getApproved(uint256 _tokenId) public view returns (address);

    function isApprovedForAll(address _owner, address _operator) public view returns (bool);

}

/// @dev Note: the ERC-165 identifier for this interface is 0x150b7a02 -> magic value
interface ERC721TokenReceiver {
    /// @return `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`
    function onERC721Received(address _operator, address _from, uint256 _tokenId, bytes _data) public returns(bytes4);
}
interface ERC165 {
    function supportsInterface(bytes4 interfaceID) public view returns (bool);
}


// ERC721 인터페이스 상속받음. 인터페이스 안 함수들 구현필요
contract ERC721implementation is ERC721{
    // token id를 key값으로 계정을 return
    mapping (uint256 => address) tokenOwner;
    // 해당 계정이 몇개의 토큰을 소유하고있는지 int return
    mapping (address => uint256) ownedTokensCount;
    // 해당 토큰의 권한을 갖게 된 계정 저장
    mapping (uint256 => address) tokenApprovals;
    // 누가 => 누구에게 => 권한부여를 했는가
    mapping (address => mapping (address => bool)) operatorApprovals;
    // 특정 인터페이스를 쓰는가 (bytes4: 인터페이스 식별값)
    mapping (bytes4 => bool) supportsInterfaces;

    constructor () public {
        supportsInterfaces[0x80ac58cd] = true;
    }

    function mint(address _to, uint _tokenId) public {
        tokenOwner[_tokenId] = _to;
        // 토큰 발행시마다 토큰 개수 +1
        ownedTokensCount[_to] += 1;
    }

    // owner를 넘기면 owner계정이 소유한 토큰의 개수 return
    function balanceOf(address _owner) public view returns (uint256) {
        return ownedTokensCount[_owner];
    }
    // tokenId를 넘기면 토큰의 주인을 return
    function ownerOf(uint256 _tokenId) public view returns (address) {
        return tokenOwner[_tokenId];
    }
    // token을 from계정에서 to계정으로 전송
    function transferFrom(address _from, address _to, uint256 _tokenId) public{
        address owner = ownerOf(_tokenId);
        // 함수 호출 계정과 owner계정이 같은지 확인 or 전송권한있는 계정인지 확인
        require(msg.sender == owner || getApproved(_tokenId) == msg.sender || isApprovedForAll(owner, msg.sender));
        // from과 to 계정이 비어있지 않아야함
        require(_from != address(0));
        require(_to != address(0));
        // from계정 토큰 개수 -1
        ownedTokensCount[_from] -= 1;
        // 토큰 소유권 삭제
        tokenOwner[_tokenId] = address(0);
        // to계정 토큰 개수 +1
        ownedTokensCount[_to] += 1;
        // 토큰 소유권 주기
        tokenOwner[_tokenId] = _to;
    }
    // contract계정으로 토큰 전송 시 contract에 토큰을 다루는 기능이 없다면 토큰 증발 -> 이 문제 해결!
    // to계정이 contract계정일 경우 ERC721 호환성이 있는지 check
    function safeTransferFrom(address _from, address _to, uint256 _tokenId) public {
        transferFrom(_from, _to, _tokenId);
        // constract 계정일 경우 토큰을 받을 수 있는지 확인
        if (isContract(_to)) {
            //onERC721Received에서 magic value return하는지 확인
            bytes4 returnValue = ERC721TokenReceiver(_to).onERC721Received(msg.sender, _from, _tokenId, '');
            require(returnValue == 0x150b7a02);
        }
    }
    // token을 contract로 보낼 때 해당 contract이 data field를 요구하는 경우
    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes data) public {
        transferFrom(_from, _to, _tokenId);
        // constract 계정일 경우 토큰을 받을 수 있는지 확인
        if (isContract(_to)) {
            //onERC721Received에서 magic value return하는지 확인
            bytes4 returnValue = ERC721TokenReceiver(_to).onERC721Received(msg.sender, _from, _tokenId, data);
            require(returnValue == 0x150b7a02);
        }
    }
    // token을 계정에 approve
    function approve(address _approved, uint256 _tokenId) public{
        // 권한을 받게되는 계정이 이미 token을 소유한 계정이 아니어야함
        address owner = ownerOf(_tokenId);
        require(_approved != owner);
        // approve 함수를 호출한 계정이 tokenId의 소유자여야 함
        require(msg.sender == owner);
        tokenApprovals[_tokenId] = _approved;
    }
    // tokenId를 받아 주소를 return
    function getApproved(uint256 _tokenId) public view returns (address) {
        // 해당 토큰의 전송 권한이 있는 계정 주소 return
        return tokenApprovals[_tokenId];
    }

    // 계정이 소유한 모든 token들을 전송할 수 있도록 권한 부여
    // operator : 권한 부여할 계정, _approved : 부여할건지의 여부
    function setApprovalForAll(address _operator, bool _approved) public {
        require(_operator != msg.sender);
        // sender가 operator에 권한을 부여할것인지 _approved 인자를 통해 mapping에 저장
        operatorApprovals[msg.sender][_operator] = _approved;
    }

    // 토큰의 소유자가 operator에게 권한을 부여했는지?
    function isApprovedForAll(address _owner, address _operator) public view returns (bool){
        return operatorApprovals[_owner][_operator];
    }

    // ERC721를 구현하고 있는지?
    function supportsInterface(bytes4 interfaceID) public view returns (bool){
        return supportsInterfaces[interfaceID];
    }

    function isContract(address _addr) private view returns (bool) {
        uint256 size;
        assembly { size := extcodesize(_addr) }
        // return값이 0보다 크면 true -> contract 계정이라는 뜻
        return size > 0;
    }
}
// 경매를 담당하는 contract
contract Auction is ERC721TokenReceiver{
    function onERC721Received(address _operator, address _from, uint256 _tokenId, bytes _data) public returns(bytes4){
        // 0x150b7a02 return
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }

    function checkSupportsInterface(address _to, bytes4 interfaceID) public view returns (bool) {
        return ERC721implementation(_to).supportsInterface(interfaceID);
    }
}
