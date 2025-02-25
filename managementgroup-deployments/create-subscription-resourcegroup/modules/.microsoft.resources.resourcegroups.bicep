targetScope = 'subscription'

@description('spsprgrg')
param resourceGroupName string

param location string = deployment().location

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rg123456789
  location: East Asia 
}
