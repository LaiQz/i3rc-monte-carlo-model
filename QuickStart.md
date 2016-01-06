(This information is repeated in the file Readme.txt in the root directory.)

Before you can solve a radiative transfer problem you have to define the (three-dimensionally varying) properties of the atmosphere. These are often  specified in terms of the concentration and sizes of cloud and aerosol problems, for which the optical properties must first be computed. That is, one must
  * compute the single scattering properties of cloud and/or aerosol particles,  probably as a function of particle size, at appropriate wavelength, then
  * describe the three-dimensional distribution of particles within the domain, then
  * compute the radiative transfer.

We've provided programs that correspond to each step:
  * [Tools/MakeMieTable](http://code.google.com/p/i3rc-monte-carlo-model/source/browse/#svn/tags/Cornish-Gilliflower/Tools) creates a table of single scattering properties at a given  wavelength for a size distribution of spheres as a function of size
  * [Tools/PhysicalPropertieToDomain](http://code.google.com/p/i3rc-monte-carlo-model/source/browse/#svn/tags/Cornish-Gilliflower/Tools) reads several kinds of formatted ASCII files describing concentration, drop sizes or numbers, etc., combines them with the phaseFunctionTables, and produces a file describing the domain   ([Tools/OpticalPropertiesToDomain](http://code.google.com/p/i3rc-monte-carlo-model/source/browse/#svn/tags/Cornish-Gilliflower/Tools) can be used if the optical properties, rather  than the physical properties, are available).
  * [Example-Drivers/monteCarloDriver](http://code.google.com/p/i3rc-monte-carlo-model/source/browse/#svn/tags/Cornish-Gilliflower/Example-Drivers) reads the domain, computes the radiative transfer, and writes out the results. It can use MPI to run in parallel if the useMPI flag is set to "yes" in the Makefile in the root directory

If what you need are fluxes or intensities at the domain boundaries or heating rates within the domain, you can almost certainly use our programs to solve  your problem and won't need to program anything yourself.

In the language of the Programmer's Guide (available in the Downloads section), the three steps correspond to the  creation of three objects:
  * a phaseFunctionTable (from module scatteringPhaseFunctions),
  * a domain (from module opticalProperties), and
  * an integrator (from module monteCarloRadiativeTransfer) which processes a set of photons (from module monteCarloIllumination).

Problems can also be solved by creating phaseFunctionTables and domains using calls from Fortran code, saving them using the write functions included in the modules, then using our driver programs to compute the radiative transfer. An example program that converts cloud fields from a large-eddy simulation to domain files is available under the [Downloads tab](http://code.google.com/p/i3rc-monte-carlo-model/downloads/list) above.