function New-DynamicParameterFn
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]
        $Name,

        [Parameter(ValueFromPipelineByPropertyName)]
        [Type]
        $Type  = [Object], #This is what parameters default to in PS, so we keep this default

        [Parameter(ValueFromPipelineByPropertyName)]
        [string[]]
        $Alias
    )

    DynamicParam
    {
        $dictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        
        $attributeParameters = [System.Management.Automation.ParameterAttribute].GetMembers() | Where {$_.MemberType -eq 'Property' -and $_.CanWrite -eq $true}

        # Should always evaluate to $true, but we already went through so much trouble to ensure we get and use 
        # only attributes we know for a fact are available that we might as well do the check here too... 
        if ($attributeParameters.Name -contains 'ValueFromPipelineByPropertyName')
        {
            $attributes = @{ValueFromPipelineByPropertyName = $true}
        }

        foreach ($attributeParameter in $attributeParameters)
        {
            $parameter = New-PrivateDynamicParameterFn -Name $attributeParameter.Name -Type $attributeParameter.PropertyType -Attributes $attributes
            $dictionary.Add($attributeParameter.Name, $parameter)
        }

        $validationParameters = Get-AssemblyTypes -Type System.Management.Automation.ActionPreference | Where {$_.BaseType -Match 'Validate(Enumerated)?ArgumentsAttribute|CmdletMetadataAttribute' -and $_.IsPublic -eq $true -and $_.IsAbstract -eq $false}

        foreach ($validationParameter in $validationParameters)
        {
            $argument = @{}
            $constructors = $validationParameter.GetConstructors()
                    
            $argument.Name = $validationParameter.Name

            if ($constructors.Count -eq 1)
            {
                $parameters = $constructors.GetParameters()
                        
                switch ($parameters.Count)
                {
                    0 {$argument.Type = [switch]}
                    1 {$argument.Type = $parameters.ParameterType.Name}
                    default 
                    {
                        for ($i = 0; $i -lt $parameters.Count -1; $i++)
                        {
                            $differentTypes = $false
                            if ($parameters[$i].ParameterType.Name -ne $parameters[$i + 1].ParameterType.Name)
                            {
                                $differentTypes = $true
                                break
                            }
                        }

                        if ($differentTypes)
                        {
                            $argument.Type = [Object[]]
                        }
                        else 
                        {
                            $argument.Type = "$($parameters[0].ParameterType.Name)[]"
                        }
                    }
                }
            } 
            elseif ($constructors.Count -gt 1)
            {
                # Crap, multiple constructors, which one do we choose?? 
                # Just make the argument type Object[] which covers everything!

                # Yes, we could just make it Object, but I like Object[] more.
                $argument.Type = [Object[]]
            }

            $parameter = [PSCustomObject] $argument | New-PrivateDynamicParameterFn
                       
            $dictionary.Add($argument.Name, $parameter)
        }
        
        $dictionary
    }

    Process
    {
        $attributes = @{}
        foreach ($attributeParameter in $attributeParameters)
        {
            if ($PSBoundParameters[$attributeParameter.Name])
            {
                $attributes.($attributeParameter.Name) = if ($Dictionary[$attributeParameter.Name].ParameterType.Name -ne 'switch') {$dictionary[$attributeParameter.Name].Value} 
            }
        }

        $validations = @{}
        foreach ($validationParameter in $validationParameters)
        {
            if ($PSBoundParameters[$validationParameter.Name])
            {
                $validations.($validationParameter.Name) = if ($Dictionary[$validationParameter.Name].ParameterType.Name -ne 'SwitchParameter') {$dictionary[$validationParameter.Name].Value} 
            }
        }

        if ($Alias)
        {
            $validations.AliasAttribute = $Alias
        }

        New-PrivateDynamicParameterFn -Name $Name -Type $Type -Validations $validations -Attributes $attributes
    }
}

function New-PrivateDynamicParameterFn
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]
        $Name,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Type]
        $Type,

        [Parameter(ValueFromPipelineByPropertyName)]
        [Hashtable]
        $Validations,

        [Parameter(ValueFromPipelineByPropertyName)]
        [Hashtable]
        $Attributes
    )

    Process
    {
        $paramAttribute = New-Object System.Management.Automation.ParameterAttribute
        $attributeCollection = New-Object 'Collections.ObjectModel.Collection[System.Attribute]'

        foreach ($attributeKey in $Attributes.Keys)
        {
            $paramAttribute.$attributeKey = $Attributes[$attributeKey]
        }

        $attributeCollection.Add($paramAttribute)

        foreach ($validationKey in $Validations.Keys)
        {
            $a = New-Object -TypeName "System.Management.Automation.$validationKey" -ArgumentList $Validations[$validationKey]
            $attributeCollection.Add($a)
        }

        New-Object -TypeName System.Management.Automation.RuntimeDefinedParameter -ArgumentList @($Name, $Type, $attributeCollection)
    }
}

function Get-AssemblyTypes
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Type]
        $Type
    )

    Process
    {
        $assembly = [System.Reflection.Assembly]::GetAssembly($Type)
        $assemblyName = $assembly.GetName().Name
        $assembly.GetTypes() | Where Namespace -eq $assemblyName
    }
}
