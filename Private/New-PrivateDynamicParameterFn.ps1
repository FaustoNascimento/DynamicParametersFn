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
        $Attributes,

        [Parameter(ValueFromPipelineByPropertyName)]
        [object]
        $DefaultValue
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

        $parameter = New-Object -TypeName System.Management.Automation.RuntimeDefinedParameter -ArgumentList @($Name, $Type, $attributeCollection)

        if ($PSBoundParameters.ContainsKey('DefaultValue'))
        {
            if (@($DefaultValue.PSObject.Methods.Name) -contains 'Equals')
            {
                if ($DefaultValue.Equals($PSBoundParameters['DefaultValue']))
                {
                    $parameter.Value = $DefaultValue
                }
            }
            else
            {
                if ($DefaultValue -eq $PSBoundParameters['DefualtValue'])
                {
                    $parameter.Value = $DefaultValue
                }
            }
        }

        $parameter
    }
}
