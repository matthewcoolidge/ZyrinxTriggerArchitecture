/*
 * @description: Trigger Action to handle INSERT or UPDATE the phone numbers, including:
 *               https://theknotww.atlassian.net/browse/QTC-6113
 * @author: Nick
 * @date: 2023-06-11
 */

public without sharing class AccountTriggerActionBefore implements TKWWTriggerArchitecture.executeMethod {
    
    public void execute(List <sObject> records, Map <id, sObject> oldMap, TKWWTriggerArchitecture.triggerParameters tp)
    {
        List<String> phoneList = new List<String>();
        if(tp.isInsert || tp.isUpdate){

            for(Account record : (List<Account>)records){
                if(needToCleansePhone(record)){
                    phoneList.add(record.phone);
                }
            }
            System.debug(LoggingLevel.INFO, '*** phoneList: ' + phoneList);

            if(!phoneList.isEmpty()){
                Map<String, String> mapCleansedPhoneNumbers = Engine.getCleansedNumbers(phoneList);

                // Assigned the cleanse phone number
                for(Account record : (List<Account>)records){
                    if(mapCleansedPhoneNumbers.containsKey(record.Phone)){
                        System.debug(LoggingLevel.INFO, '*** record.Phone: ' + record.Phone);
                        if(!hasPrefix(record.Phone)){
                            System.debug(LoggingLevel.INFO, '*** addPrefix');
                            record.Phone = addPrefix(mapCleansedPhoneNumbers.get(record.Phone));
                        }
                    }
                }
            }
        }
    }

    // only work for those Unites states and Canada accounts
    private Boolean needToCleansePhone(Account acc){
        Boolean b = false;
        if(acc.BillingCountryCode == 'US' || acc.BillingCountryCode == 'CA'){
            b = true;
        }
        return b;
    }

    private Boolean hasPrefix(String phoneVal){
        Boolean b = false;
        if(phoneVal.startsWith('+1')){
            b = true;
        }
        return b;
    }
    private String addPrefix(String phoneVal){
        String val = phoneVal;
        if(val.startsWith('+1')){
            val = val;
        }
        else{
            val = '+1'+val;
        }
        return val;
    }
}