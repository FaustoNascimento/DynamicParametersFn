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
        [Object]
        $DefaultValue
    )

    DynamicParam
    {
        $dictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        
        $attributeParameters = [System.Management.Automation.ParameterAttribute].GetMembers() | Where {$_.MemberType -eq 'Property' -and $_.CanWrite -eq $true}

        # Should always evaluate to $true, but we already went through so much trouble to ensure we get and use 
        # only attributes we know for a fact are available that we might as well do the check here too... 
        if ($attributeParameters.Name -contains 'ValueFromPipelineByPropertyName')
        {
            # Make all of the dynamic attributes accept value from pipeline by property name
            $attributes = @{ValueFromPipelineByPropertyName = $true}
        }

        foreach ($attributeParameter in $attributeParameters)
        {
            $parameter = New-PrivateDynamicParameterFn -Name $attributeParameter.Name -Type $attributeParameter.PropertyType -Attributes $attributes
            $dictionary.Add($attributeParameter.Name, $parameter)
        }

        $validationParameters = Get-AssemblyTypes -Type System.Management.Automation.ActionPreference | Where-Object `
            {($_.BaseType -Match 'Validate(Enumerated)?ArgumentsAttribute|CmdletMetadataAttribute' -or 
            $_.Name -Match 'AliasAttribute|CredentialAttribute') -and $_.IsPublic -eq $true -and $_.IsAbstract -eq $false}

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

            $parameter = [PSCustomObject] $argument | New-PrivateDynamicParameterFn -Attributes $attributes
                       
            $dictionary.Add($argument.Name, $parameter)
        }
        
        $dictionary
    }

    Process
    {
        $attributes = @{}
        foreach ($attributeParameter in $attributeParameters)
        {
            if ($dictionary[$attributeParameter.Name].Value)
            {
                $attributes.($attributeParameter.Name) = if ($Dictionary[$attributeParameter.Name].ParameterType.Name -ne 'SwitchParameter') {$dictionary[$attributeParameter.Name].Value} 
            }
        }

        $validations = @{}
        foreach ($validationParameter in $validationParameters)
        {
            if ($dictionary[$validationParameter.Name].Value)
            {
                $validations.($validationParameter.Name) = if ($Dictionary[$validationParameter.Name].ParameterType.Name -ne 'SwitchParameter') {$dictionary[$validationParameter.Name].Value} 
            }
        }

        New-PrivateDynamicParameterFn -Name $Name -Type $Type -Validations $validations -Attributes $attributes -DefaultValue $DefaultValue
    }
}
