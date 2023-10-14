import "@stdlib/deploy";

/*
  TASK 3 - DEX
  Create a simple jetton dex contract that trades one pair of jettons: A and B.
  The price of jettons depends on the amount of jettons that smart contract has.
  Therefore, the smart contract needs to keep track of how much jettons it has.
  
  Price for the jetton A in swap B->A should be calculated by formula "amountOfJettonAOnContract * decimal / amountOfJettonBOnContract".
  Decimals are only needed for price accuracy. It should be set as 1e9.
  So, if smart contract has 10 of jetton A and 2 of jetton B, then after sending 1 jetton B you should receive 5 of jettons A.

  If smart contract pool doesn't have enough jettons to trade
  (for example someone sends 99999 jettons of B, but dex pool only has 10 of jettons A),
  then sent incoming jettons (B, in our example) back to the sender.

  If smart contract receives a different jetton (neither A nor B) then throw an error.

  Implement a getter that returns the number of jettons in the pool and
  one more to get the price of jetton A or jetton B.
  Getters' behavior with incorrect parameter (address other than that of jetton A or B)
  is undefined (there are no such tests).
  
  Note:
  Admin can add jettons A and B just by sending them to the smart contract (we need to add initial supply to the pool for it to be functional).
  To be exact: any jettons (A or B) received from the admin are "added". Admin can't swap.
*/

message(0x7362d09c) JettonNotification {
    queryId: Int as uint64;
    amount: Int as coins;
    from: Address;
    forwardPayload: Slice as remaining;
}

message(0xf8a7ea5) JettonTransfer {
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
  aAmount: Int;
  bAmount: Int;
  jettonAddressA: Address;
  jettonAddressB: Address;
  decimal: Int;

  init(admin: Address, newJettonAddressA: Address, newJettonAddressB: Address) {
    self.owner = admin;
    self.jettonAddressA = newJettonAddressA;
    self.jettonAddressB = newJettonAddressB;
    self.aAmount = 0;
    self.bAmount = 0;
    self.decimal = 1000000000;
  }

  receive(msg: JettonNotification) {
    let jettonAddress: Address = sender();
    require(jettonAddress == self.jettonAddressA || jettonAddress == self.jettonAddressB, "not an paired jetton");
    let sender: Address = msg.from;
    let amount: Int = msg.amount;
    let jettonA: Bool = false;
    if(jettonAddress == self.jettonAddressA) { jettonA = true; }
    if(sender == self.owner) {
      if(jettonA) { self.aAmount = self.aAmount + amount; }
      else { self.bAmount = self.bAmount + amount; }
    } else {
      let price: Int = self.price(jettonAddress); // 5000000000
      let to_recv: Int = (amount * price) / self.decimal; // 1000000000 * 5000000000 = 5000000000000000000 / 1000000000
      let dest: Address = jettonAddress;
      if(jettonA) {
        if(self.bAmount < to_recv) {
          dest = self.jettonAddressA;
          to_recv = amount;
        } else {
          self.aAmount = self.aAmount - amount;
        }
      } else {
        if(self.aAmount < to_recv) {
          dest = self.jettonAddressB;
          to_recv = amount;
        } else {
          self.bAmount = self.bAmount - amount;
        }
      }
      
        send(SendParameters{
            to: dest,
            value: 0,
            mode: SendRemainingValue + SendIgnoreErrors,
            bounce: true, 
            body: JettonTransfer {
                queryId: msg.queryId,
                amount: to_recv,
                destination: sender,
                responseDestination: sender,
                customPayload: null,
                forwardTonAmount: context().value,
                forwardPayload: msg.forwardPayload
            }.toCell()
            }
        );
    }
  } 
  
  get fun price(jetton: Address): Int { 
    if(jetton == self.jettonAddressA) {
      return self.aAmount * self.decimal / self.bAmount; // amountOfJettonAOnContract * decimal / amountOfJettonBOnContract 10 * 1000000000 / 2 = 5000000000
    } else if(jetton == self.jettonAddressB) {
      return self.bAmount * self.decimal / self.aAmount; //
    } else {
      return 0;
    }
  }
  
  get fun balance(jetton: Address): Int { 
    if(jetton == self.jettonAddressA) {
      return self.aAmount;
    } else if(jetton == self.jettonAddressB) { 
      return self.bAmount;
    } else {
      return 0;
    } 
  }
}