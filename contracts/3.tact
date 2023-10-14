import "@stdlib/deploy";

/*
TASK 3 - Dex contract 
  Create a simple Jetton dex contract that trades one pair of tokens A and B.
  The price of tokens depends on the amount of tokens that smartcontract has.
  So, if smartcontract has 10 tokens A and 2 tokens B, then after sending 1 token B you will receive 5 tokens A.
  
  If the user will pool don't have enough tokens to trade
  (for example, someone will send 99999 B tokens and dex pool has only 10 of tokens A),
  then return sent ("B" in our example) tokens back to the user.

  Implement a getter that will give the number of tokens in the pool and
  one more to get the price of token A or token B.
  
  Note
  Admin can add token A and token B just by sending them to smartcontract (we need to set the initial supply for the pool).
*/

message(0x7362d09c) TokenNotification {
    queryId: Int as uint64;
    amount: Int as coins;
    from: Address;
    forwardPayload: Slice as remaining;
}

message(0xf8a7ea5) TokenTransfer {
    queryId: Int as uint64;
    amount: Int as coins;
    destination: Address;
    responseDestination: Address?;
    customPayload: Cell?;
    forwardTonAmount: Int as coins;
    forwardPayload: Slice as remaining;
}

contract Task3 with Deployable {
  owner: Address;
  a: Int;
  b: Int;
  jAddressA: Address;
  jAddressB: Address;
  decimal: Int;

  init(admin: Address, newJAddressA: Address, newJAddressB: Address) {
    self.owner = admin;
    self.jAddressA = newJAddressA;
    self.jAddressB = newJAddressB;
    self.a = 0; // 10
    self.b = 0; // 2
    self.decimal = 1000000000;
  }

  receive(msg: TokenNotification) {
    let jettonAddress: Address = sender();
    self.onlyPaired(jettonAddress);
    let sender: Address = msg.from;
    let amount: Int = msg.amount;
    let jettonA: Bool = false;
    if(jettonAddress == self.jAddressA) { jettonA = true; }
    if(sender == self.owner && (self.a == 0 || self.b == 0)) {
      if(jettonA && self.a == 0) { self.a = self.a + amount; }
      else if(self.b == 0) { self.b = self.b + amount; }
    } else {
      let price: Int = self.price(jettonAddress); // 5000000000
      let to_recv: Int = (amount * price) / self.decimal; // 1000000000 * 5000000000 = 5000000000000000000 / 1000000000
      let dest: Address = jettonAddress;
      if(jettonA) {
        if(self.b < to_recv) {
          dest = self.jAddressA;
          to_recv = amount;
        } else {
          self.a = self.a - amount;
        }
      } else {
        if(self.a < to_recv) {
          dest = self.jAddressB;
          to_recv = amount;
        } else {
          self.b = self.b - amount;
        }
      }
      
        send(SendParameters{
            to: dest,
            value: 0,
            mode: SendRemainingValue + SendIgnoreErrors,
            bounce: true, 
            body: TokenTransfer {
                queryId: 0,
                amount: to_recv,
                destination: sender,
                responseDestination: myAddress(),
                customPayload: null,
                forwardTonAmount: ton("0.01"),
                forwardPayload: emptySlice()
            }.toCell()
            }
        );
    }
  } 
  
  fun onlyPaired(token: Address) {
    require(token == self.jAddressA || token == self.jAddressB, "not an paired jetton");
  }
  
  get fun price(token: Address): Int { 
    if(token == self.jAddressA) {
      return (self.b / self.a) * self.decimal; // 2 / 10 = 200000000
    } else if(token == self.jAddressB) {
      return (self.a / self.b) * self.decimal; // 10 / 2 = 5000000000
    } else {
      return 0;
    }
  }
  
  get fun balance(token: Address): Int { 
    if(token == self.jAddressA) {
      return self.a;
    } else if(token == self.jAddressB) { 
      return self.b;
    } else {
      return 0;
    }
  }
}
