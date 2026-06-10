public without sharing class ZyrinxTriggerArchitectureMetadataService {

    @TestVisible
    public static List<Trigger_Action__mdt> actions = new List<Trigger_Action__mdt>();

    @TestVisible
    public static Map<String, Trigger_Settings_Zyrinx__mdt> mapTriggerSettings;

    @TestVisible
    public static List<Trigger_Action__mdt> getTriggerActions(){

        if(actions!=null && actions.size() > 0){
            // You can override the Trigger_Action__mdt(s) stored in the database by passing Trigger_Action__mdt instance(s)
            // to the ZyrinxTriggerArchitectureMetadataService.actions before the Trigger executes
           return actions;
        }
        else{

            Map<String, Trigger_Action__mdt> mapTriggerActions = Trigger_Action__mdt.getAll();

            for(Trigger_Action__mdt thisRouting : mapTriggerActions.values()){
                if(((Test.isRunningTest() && thisRouting.isActiveForTesting__c == true) ||
                    (Test.isRunningTest() == false)) &&
                    thisRouting.Execute_Class__c != null)
                {
                    actions.add(thisRouting);
                }
            }

            /* if(Test.isRunningTest()){

                for(Trigger_Action__mdt thisRouting : mapTriggerActions.values()){
                    if(thisRouting.isActiveForTesting__c == true && thisRouting.Execute_Class__c != null){
                        actions.add(thisRouting);
                    }
                }
            }
            else{
                for(Trigger_Action__mdt thisRouting : mapTriggerActions.values()){
                    if(thisRouting.Execute_Class__c != null){
                        actions.add(thisRouting);
                    }
                }
            } */
        }
        return actions;
    }

    @TestVisible
    public static Integer getSynchronousRecordLimit(){
        
        if(mapTriggerSettings == null){
            mapTriggerSettings = Trigger_Settings_Zyrinx__mdt.getAll();
        }
        
        return (mapTriggerSettings.size() == 0 || 
                mapTriggerSettings.containsKey('Default')==false ||
                mapTriggerSettings.get('Default').SynchronousRecordLimit__c == null) 
                ? 1 
                : (Integer)mapTriggerSettings.get('Default').SynchronousRecordLimit__c;
    }

}