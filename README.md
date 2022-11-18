# Action - Publish the Powershell Modules to PSGallery
With this action you can publish powershell modules to PSGallery.
It needs the PS Gallery profile API Key and PSD1 locatioon to upload the extension.

This action reduces the complexity of adding Module / Packages to the PSGallery, which can be publically availabl for install.

## example 1

```yml
 workflow_dispatch:
    inputs:
      modulePath:
        description: "Provide the module path that includes .psd1"
        required: true
      NuGetApiKey:
        description: "Provide NuGetApiKey for your profile in PSGallery."
        required: true

# A workflow run is made up of one or more jobs that can run sequentially or in parallel
jobs:
  # This workflow contains a single job called "build"
  publish_module:
    # The type of runner that the job will run on
    runs-on: windows-latest

    # Steps represent a sequence of tasks that will be executed as part of the job
    steps:
      # Checks-out your repository under $GITHUB_WORKSPACE, so your job can access it
      - uses: actions/checkout@v2

      - id: publishpsmodule
        uses: aammirmirza/AzCostOptimization@PSGallery_v2
        with:
          NuGetApiKey: ${{ github.event.inputs.NuGetApiKey }}
          modulePath: ${{ github.event.inputs.modulePath }}
```
In the above example I am passing ```NuGetApiKey``` and ```modulePath``` as runtime arguments. But it can also be coded in the same place withinn the workflow, as shown in the example below.

During runtime you can pass the arguments as:
NuGetApiKey : '${{ secrets.NuGetApiKey }}'
modulePath : 'path to your .psd1 file folder'

## example 1

```yml
      - id: publishpsmodule
        uses: aammirmirza/AzCostOptimization@PSGallery_v2
        with:
          NuGetApiKey: '${{ secrets.NuGetApiKey }}'
          modulePath: 'path to your .psd1 file folder'
```