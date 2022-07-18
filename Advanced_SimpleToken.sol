// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.10;

interface ERC20Interface {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function transferFrom(address spender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Transfer(address indexed spender, address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 oldAmount, uint256 amount);
}

library SafeMath {
  	function mul(uint256 a, uint256 b) internal pure returns (uint256) {
			uint256 c = a * b;
			assert(a == 0 || c / a == b);
			return c;
  	}

  	function div(uint256 a, uint256 b) internal pure returns (uint256) {
	    uint256 c = a / b;
			return c;
  	}

  	function sub(uint256 a, uint256 b) internal pure returns (uint256) {
			assert(b <= a);
			return a - b;
  	}

  	function add(uint256 a, uint256 b) internal pure returns (uint256) {
			uint256 c = a + b;
			assert(c >= a);
			return c;
	}
}

abstract contract OwnerHelper {
  	address public _owner;
    address[3] private _owners;
    mapping(address=>uint8) private voteCount;
    mapping(address=>uint8) private voteResult;

  	event OwnershipTransferred(address indexed preOwner, address indexed nextOwner);

  	modifier onlyOwner {
			require(msg.sender == _owner, "OwnerHelper: caller is not owner");
			_;
  	}
    
  	constructor() {
      _owner = msg.sender;
      _owners[0] = msg.sender;
      voteCount[msg.sender] = 0;
      voteResult[msg.sender] = 0;
  	}

    function owner() public view virtual returns (address) {
      return _owner;
    }

  	function transferOwnership(address newOwner) onlyOwner public {
      require(newOwner != _owner);
      require(newOwner != address(0x0));
      address preOwner = _owner;
	    _owner = newOwner;
	    emit OwnershipTransferred(preOwner, newOwner);
  	}

    // 관리자를 추가하기 위한 함수
    function addOwner(uint8 _ownerNumber, address _newOwner) onlyOwner public returns(bool){
        require(_ownerNumber > 0 && _ownerNumber < 3);
        _owners[_ownerNumber] = _newOwner;
        voteCount[_newOwner] = 0;
        voteResult [_newOwner] = 0;
        return true;
    }

    function voteForOwner(address _voteForAddress) public virtual returns(bool){
        _voteForOwner(msg.sender, _voteForAddress);
        return true;
    }

    function _voteForOwner(address sender, address voteForAddress) internal virtual returns(bool){
        require(_owners[0] == sender || _owners[1] == sender || _owners[2] == sender);
        require(voteCount[sender] == 0);
        require(sender != voteForAddress);
        voteResult[voteForAddress] += 1;
        voteCount[sender] += 1;
        return true;
    }

    function result() public view returns(uint8) {
        return voteResult[msg.sender];
    }

    function transferOwnershipByVote() onlyOwner public returns(bool){

        uint8 max = 0;
        address maxCandidates;
        
        for(uint8 i=0; i<_owners.length; i++){
          if(voteResult[_owners[i]] > max){
            max = voteResult[_owners[i]];
            maxCandidates = _owners[i];
          }
        }
        require(maxCandidates != _owner);
        require(maxCandidates != address(0x0));
        address preOwner = _owner;
        _owner = maxCandidates;
        emit OwnershipTransferred(preOwner, maxCandidates);
        return true;
    }


}

contract SimpleToken is ERC20Interface, OwnerHelper {
    using SafeMath for uint256; 

    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) public _allowances;

    uint256 public _totalSupply;
    string public _name;
    string public _symbol;
    uint8 public _decimals;
    bool public _tokenLock;
    mapping (address => bool) public _personalTokenLock;

    constructor(string memory getName, string memory getSymbol) {
      _name = getName;
      _symbol = getSymbol;
      _decimals = 18;
      _totalSupply = 100000000e18;
      _balances[msg.sender] = _totalSupply;
      _tokenLock = true;
    }

    function name() public view returns (string memory) {
      return _name;
    }

    function symbol() public view returns (string memory) {
      return _symbol;
    }

    function decimals() public view returns (uint8) {
      return _decimals;
    }

    function totalSupply() external view virtual override returns (uint256) {
      return _totalSupply;
    }

    function balanceOf(address account) external view virtual override returns (uint256) {
      return _balances[account];
    }

    function transfer(address recipient, uint amount) public virtual override returns (bool) {
      _transfer(msg.sender, recipient, amount);
      emit Transfer(msg.sender, recipient, amount);
      return true;
    }

    function allowance(address owner, address spender) external view override returns (uint256) {
      return _allowances[owner][spender];
    }

    function approve(address spender, uint amount) external virtual override returns (bool) {
      uint256 currentAllowance = _allowances[msg.sender][spender];
      require(_balances[msg.sender] >= amount,"ERC20: The amount to be transferred exceeds the amount of tokens held by the owner.");
      _approve(msg.sender, spender, currentAllowance, amount);
      return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external virtual override returns (bool) {
      _transfer(sender, recipient, amount);
      emit Transfer(msg.sender, sender, recipient, amount);
      uint256 currentAllowance = _allowances[sender][msg.sender];
      require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
      _approve(sender, msg.sender, currentAllowance, currentAllowance - amount);
      return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
      require(sender != address(0), "ERC20: transfer from the zero address");
      require(recipient != address(0), "ERC20: transfer to the zero address");
      require(isTokenLock(sender, recipient) == false, "TokenLock: invalid token transfer");
      uint256 senderBalance = _balances[sender];
      require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
      _balances[sender] = senderBalance.sub(amount);
      _balances[recipient] = _balances[recipient].add(amount);
    }

    function isTokenLock(address from, address to) public view returns (bool lock) {
      lock = false;

      if(_tokenLock == true)
      {
           lock = true;
      }

      if(_personalTokenLock[from] == true || _personalTokenLock[to] == true) {
           lock = true;
      }
    }

    function removeTokenLock() onlyOwner public {
      require(_tokenLock == true);
      _tokenLock = false;
    }
    function removePersonalTokenLock(address _who) onlyOwner public {
      require(_personalTokenLock[_who] == true);
      _personalTokenLock[_who] = false;
    }

    function _approve(address owner, address spender, uint256 currentAmount, uint256 amount) internal virtual {
      require(owner != address(0), "ERC20: approve from the zero address");
      require(spender != address(0), "ERC20: approve to the zero address");
      require(currentAmount == _allowances[owner][spender], "ERC20: invalid currentAmount");
      _allowances[owner][spender] = amount; 
      emit Approval(owner, spender, currentAmount, amount);
    }

    // Lock을 재활용 해보자
    function addTokenLock() onlyOwner public{
      require(_tokenLock == false);
      _tokenLock = true;
    }

    function addPersonalTokenLock(address _who) onlyOwner public{
      require(_personalTokenLock[_who] == false);
      _personalTokenLock[_who] = true;
    }

}