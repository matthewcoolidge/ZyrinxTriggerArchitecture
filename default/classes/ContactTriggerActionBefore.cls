/*
 * @description: Trigger Action to handle INSERT or UPDATE the phone numbers, including:
 *               https://theknotww.atlassian.net/browse/QTC-6113
 * @author: Nick
 * @date: 2023-06-11
 */
public without sharing class ContactTriggerActionBefore implements TKWWTriggerArchitecture.executeMethod {

    public void execute(List <sObject> records, Map <id, sObject> oldMap, TKWWTriggerArchitecture.triggerParameters tp)
    {
        List<String> conList = new List<String>();
        if(tp.isInsert || tp.isUpdate){

            for(Contact record : (List<Contact>)records){
                if(needToCleansePhone(record)){
                    if(String.isNotBlank(record.phone)){
                        conList.add(record.Phone);
                    }
                    if(String.isNotBlank(record.MobilePhone)){
                        conList.add(record.MobilePhone);
                    }
                }
            }
            System.debug(LoggingLevel.INFO, '*** conList: ' + conList);
            if(!conList.isEmpty()){
                Map<String, String> mapPhoneNumbers = Engine.getCleansedNumbers(conList);
                Map<String, String> mapMobile = Engine.getCleansedNumbers(conList);

                // Assigned the cleanse phone number
                for(Contact record : (List<Contact>)records){
                    if(mapPhoneNumbers.containsKey(record.Phone)){
                        if(!hasPrefix(record.Phone)){
                            record.Phone = addPrefix(mapPhoneNumbers.get(record.Phone));
                        }
                    }
                    if(mapMobile.containsKey(record.MobilePhone)){
                        if(!hasPrefix(record.MobilePhone)){
                            record.MobilePhone = addPrefix(mapMobile.get(record.MobilePhone));
                        }
                    }
                }
            }
        }
    }

    // only work for those Unites states and Canada contacts
    private Boolean needToCleansePhone(Contact con){
        Boolean b = false;
        if(con.MailingCountryCode == 'US' || con.MailingCountryCode == 'CA'){
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