/* 
 * @description: TKWWTA Cache Class for Opportunity Trigger Actions
 * @author: Matthew Coolidge
 * @date: 2022-06-02
 */
public without sharing class OpportunityTriggerCache implements TKWWTriggerArchitecture.triggerCache {

    public static Map<String, Id> botUserIdMap = new Map<String, Id>();
    public static Set<String> accountIds = new Set<String>();
    public static Map<Id, Account> activeAccountsById = new Map<Id, Account>();

    public static void init(String action){

        System.debug('OpportunityTriggerCache.init - ' + action);

        Set<String> botNames = new Set<String>();
        Map<String, OpportunityClosedLostSetting__mdt> definedClosedLostReasonsMap = OpportunityClosedLostMetadataService.getDefinedClosedLostReasonsMap();
        for(OpportunityClosedLostSetting__mdt thisSetting : definedClosedLostReasonsMap.values()){
            if(thisSetting.AccountOwnershipBot__c != null){
                botNames.add(thisSetting.AccountOwnershipBot__c);
            }
        }
        List<User> botUsers = [SELECT Id, Name FROM User WHERE Name IN :botNames];
        for(User botUser : botUsers){
            botUserIdMap.put(botUser.Name, botUser.Id);
        }

        accountIds = Pluck.strings(Opportunity.AccountId, Trigger.new, true);
        activeAccountsById = new Map<Id, Account>([SELECT Id FROM Account WHERE Account_Status__c = 'Active' AND Id IN :accountIds]);
    }
}