import credits.aleo;

// The 'mtsp' program.
program zump8_v0_1_0.aleo {
  struct Token {
    name: u128, // ASCII text represented in bits, and the u128 value of the bitstring
    symbol: u128, // ASCII text represented in bits, and the u128 value of the bitstring
    decimals: u8,
    supply: u128,
    token_owner: address
  }

  struct TokenOwner {
    account: address,
    token_name: u128
  }

  struct Balance {
    token_name: u128,
    account: address,
    balance: u128
  }

  const PRICE_PER_TOKEN: u128 = 1u128;
  mapping registered_tokens: u128 => Token;
  mapping balances: field => Balance; // hash(token_name, account) => Balance

  async transition register_token(
    public name: u128,
    public symbol: u128
    ) -> Future {
    let token: Token = Token {
      name: name,
      symbol: symbol,
      decimals: 6u8,
      supply: 1_000_000_000_000_000u128,
      token_owner: self.caller
    };

    return finalize_register_token(token);
  }

  async function finalize_register_token(token: Token) {
    // Make sure token doesn't already exist
    let token_exists: bool = registered_tokens.contains(token.name);
    assert_eq(token_exists, false);
    // Set new token
    registered_tokens.set(token.name, token);
  }

  // -------------------------
  // Called by token owners/DeFi contracts
  // -------------------------

  async transition buy(
    public token_name: u128,
    public amount: u128
  ) -> Future {
    let sender_key: TokenOwner = TokenOwner {
      account: self.caller,
      token_name: token_name
    };
    let sender_key_hash: field = BHP256::hash_to_field(sender_key);
    let fut: Future = credits.aleo/transfer_public(zump8_v0_1_0.aleo, 1u64);

    return finalize_buy(token_name, amount, self.caller, sender_key_hash, fut);
  }

  async function finalize_buy(
    token_name: u128,
    amount: u128,
    owner: address,
    sender_key_hash: field,
    transfer_fut: Future
  ) {
    transfer_fut.await();
    let balance: Balance = balances.get(sender_key_hash);
    // Assert that the balance authorization is not expired or that the token does not require authorization
    let token: Token = registered_tokens.get(token_name);
    // Update the balance, and check that the balance >= amount
    let new_balance: Balance = Balance {
      token_name: token_name,
      account: owner,
      balance: balance.balance + amount
    };
    // Update sender balance
    balances.set(sender_key_hash, new_balance);

    let new_token: Token = Token {
      name: token.name,
      symbol: token.symbol,
      decimals: token.decimals,
      supply: token.supply - amount,
      token_owner: token.token_owner
    };

    registered_tokens.set(new_token.name, new_token);
  }
}