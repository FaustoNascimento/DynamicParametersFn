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
