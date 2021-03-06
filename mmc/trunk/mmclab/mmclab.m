function varargout=mmclab(cfg,type)
%
%#############################################################################%
%         MMCLAB - Mesh-based Monte Carlo (MMC) for MATLAB/GNU Octave         %
%          Copyright (c) 2010-2015 Qianqian Fang <q.fang at neu.edu>          %
%                            http://mcx.space/mmc/                            %
%                                                                             %
%         Computational Imaging Laboratory (CIL) [http://fanglab.org]         %
%            Department of Bioengineering, Northeastern University            %
%                                                                             %
%               Research funded by NIH/NIGMS grant R01-GM114365               %
%#############################################################################%
%$Rev::      $ Last $Date::                       $ by $Author::             $%
%#############################################################################%
%
% Format:
%    [flux,detphoton,ncfg,seeds]=mmclab(cfg,type);
%
% Input:
%    cfg: a struct, or struct array. Each element in cfg defines 
%         a set of parameters for a simulation. 
%
%    It may contain the following fields:
%
%     *cfg.nphoton:     the total number of photons to be simulated (integer)
%     *cfg.prop:        an N by 4 array, each row specifies [mua, mus, g, n] in order.
%                       the first row corresponds to medium type 0 which is 
%                       typically [0 0 1 1]. The second row is type 1, and so on.
%     *cfg.node:        node array for the input tetrahedral mesh, 3 columns: (x,y,z)
%     *cfg.elem:        element array for the input tetrahedral mesh, 4 columns
%     *cfg.elemprop:    element property index for input tetrahedral mesh
%     *cfg.tstart:      starting time of the simulation (in seconds)
%     *cfg.tstep:       time-gate width of the simulation (in seconds)
%     *cfg.tend:        ending time of the simulation (in second)
%     *cfg.srcpos:      a 1 by 3 vector, the position of the source in grid unit
%     *cfg.srcdir:      a 1 by 3 vector, specifying the incident vector
%     -cfg.facenb:      element face neighbohood list (calculated by faceneighbors())
%     -cfg.evol:        element volume (calculated by elemvolume() with iso2mesh)
%     -cfg.e0:          the element ID enclosing the source, if not defined,
%                       it will be calculated by tsearchn(node,elem,srcpos);
%                       if cfg.e0 is set as one of the following characters,
%                       mmclab will do an initial ray-tracing and move
%                       srcpos to the first intersection to the surface:
%                       '>': search along the forward (srcdir) direction
%                       '<': search along the backward direction
%                       '-': search both directions
%      cfg.seed:        seed for the random number generator (integer) [0]
%                       if set as a uint8 array, the binary data in each column is used 
%                       to seed a photon (i.e. the "replay" mode)
%      cfg.detpos:      an N by 4 array, each row specifying a detector: [x,y,z,radius]
%      cfg.isreflect:   [1]-consider refractive index mismatch, 0-matched index
%      cfg.isnormalized:[1]-normalize the output flux to unitary source, 0-no reflection
%      cfg.isspecular:  [1]-calculate specular reflection if source is outside
%      cfg.ismomentum:  [0]-save momentum transfer for each detected photon
%      cfg.issaveexit:  [0]-save the position (x,y,z) and (vx,vy,vz) for a detected photon
%      cfg.issaveseed:  [0]-save the RNG seed for a detected photon so one can replay
%      cfg.basisorder:  [1]-linear basis, 0-piece-wise constant basis
%      cfg.outputformat:['ascii'] or 'bin' (in 'double')
%      cfg.outputtype:  [X] - output flux, F - fluence, E - energy deposit
%                       J - Jacobian (replay), T - approximated Jacobian (replay mode)
%      cfg.method:      ray-tracing method, [P]:Plucker, H:Havel (SSE4),
%                       B: partial Badouel, S: branchless Badouel (SSE)
%      cfg.debuglevel:  debug flag string, a subset of [MCBWDIOXATRPE], no space
%      cfg.nout:        [1.0] refractive index for medium type 0 (background)
%      cfg.minenergy:   terminate photon when weight less than this level (float) [0.0]
%      cfg.roulettesize:[10] size of Russian roulette
%      cfg.unitinmm:    defines the unit in the input mesh [1.0]
%      cfg.srctype:     source type, the parameters of the src are specified by cfg.srcparam{1,2}
%                      'pencil' - default, pencil beam, no param needed
%                      'isotropic' - isotropic source, no param needed
%                      'cone' - uniform cone beam, srcparam1(1) is the half-angle in radian
%                      'gaussian' - a collimated gaussian beam, srcparam1(1) specifies the waist radius (in voxels)
%                      'planar' - a 3D quadrilateral uniform planar source, with three corners specified 
%                                by srcpos, srcpos+srcparam1(1:3) and srcpos+srcparam2(1:3)
%                      'pattern' - a 3D quadrilateral pattern illumination, same as above, except
%                                srcparam1(4) and srcparam2(4) specify the pattern array x/y dimensions,
%                                and srcpattern is a pattern array, valued between [0-1]. 
%                      'fourier' - spatial frequency domain source, similar to 'planar', except
%                                the integer parts of srcparam1(4) and srcparam2(4) represent
%                                the x/y frequencies; the fraction part of srcparam1(4) multiplies
%                                2*pi represents the phase shift (phi0); 1.0 minus the fraction part of
%                                srcparam2(4) is the modulation depth (M). Put in equations:
%                                    S=0.5*[1+M*cos(2*pi*(fx*x+fy*y)+phi0)], (0<=x,y,M<=1)
%                      'arcsine' - similar to isotropic, except the zenith angle is uniform
%                                distribution, rather than a sine distribution.
%                      'disk' - a uniform disk source pointing along srcdir; the radius is 
%                               set by srcparam1(1) (in grid unit)
%                      'fourierx' - a general Fourier source, the parameters are 
%                               srcparam1: [v1x,v1y,v1z,|v2|], srcparam2: [kx,ky,phi0,M]
%                               normalized vectors satisfy: srcdir cross v1=v2
%                               the phase shift is phi0*2*pi
%                      'fourierx2d' - a general 2D Fourier basis, parameters
%                               srcparam1: [v1x,v1y,v1z,|v2|], srcparam2: [kx,ky,phix,phiy]
%                               the phase shift is phi{x,y}*2*pi
%                      'zgaussian' - an angular gaussian beam, srcparam1(0) specifies the variance in the zenith angle
%      cfg.{srcparam1,srcparam2}: 1x4 vectors, see cfg.srctype for details
%      cfg.srcpattern: see cfg.srctype for details
%      cfg.voidtime:   for wide-field sources, [1]-start timer at launch, 0-when entering
%                      the first non-zero voxel
%
%      fields marked with * are required; options in [] are the default values
%      fields marked with - are calculated if not given (can be faster if precomputed)
%
%    type: omit or 'omp' for multi-threading version; 'sse' for the SSE4 MMC,
%          the SSE4 version is about 25% faster, but requires newer CPUs; 
%          if type='prep' with a single output, mmclab returns ncfg only.
%
% Output:
%      flux: a struct array, with a length equals to that of cfg.
%            For each element of flux, flux(i).data is a 1D vector with
%            dimensions [size(cfg.node,1) total-time-gates] if cfg.basisorder=1,
%            or [size(cfg.elem,1) total-time-gates] if cfg.basisorder=0. 
%            The content of the array is the normalized flux (or others 
%            depending on cfg.outputtype) at each mesh node and time-gate.
%      detphoton: (optional) a struct array, with a length equals to that of cfg.
%            For each element of detphoton, detphoton(i).data is a 2D array with
%            dimensions [size(cfg.prop,1)+1 saved-photon-num]. The first row
%            is the ID(>0) of the detector that captures the photon; the second row
%            is the number of scattering events of the exitting photon; the rest rows
%            are the partial path lengths (in grid unit) traveling in medium 1 up 
%            to the last. If you set cfg.unitinmm, you need to multiply the path-lengths
%            to convert them to mm unit.
%      ncfg: (optional), if given, mmclab returns the preprocessed cfg structure,
%            including the calculated subfields (marked by "-"). This can be
%            used as the input to avoid repetitive preprocessing.
%      seeds: (optional), if give, mmclab returns the seeds, in the form of
%            a byte array (uint8) for each detected photon. The column number
%            of seed equals that of detphoton.
%
% Example:
%      cfg.nphoton=1e5;
%      [cfg.node face cfg.elem]=meshabox([0 0 0],[60 60 30],6);
%      cfg.elemprop=ones(size(cfg.elem,1),1);
%      cfg.srcpos=[30 30 0];
%      cfg.srcdir=[0 0 1];
%      cfg.prop=[0 0 1 1;0.005 1 0 1.37];
%      cfg.tstart=0;
%      cfg.tend=5e-9;
%      cfg.tstep=5e-10;
%      cfg.debuglevel='TP';
%      % populate the missing fields to save computation
%      ncfg=mmclab(cfg,'prep');
%
%      cfgs(1)=ncfg;
%      cfgs(2)=ncfg;
%      cfgs(1).isreflect=0;
%      cfgs(2).isreflect=1;
%      cfgs(2).detpos=[30 20 0 1;30 40 0 1;20 30 1 1;40 30 0 1];
%      % calculate the flux and partial path lengths for the two configurations
%      [fluxs,detps]=mmclab(cfgs);
%
%
% This function is part of Mesh-based Monte Carlo (MMC) URL: http://mcx.sf.net/mmc/
%
% License: GNU General Public License version 3, please read LICENSE.txt for details
%

if(nargin==0)
    error('input field cfg must be defined');
end
if(~isstruct(cfg))
    error('cfg must be a struct or struct array');
end

len=length(cfg);
for i=1:len
    if(~isfield(cfg(i),'node') || ~isfield(cfg(i),'elem'))
        error('cfg.node or cfg.elem is missing');
    end
    if(~isfield(cfg(i),'elemprop') ||isempty(cfg(i).elemprop) && size(cfg(i).elem,2)>4)
        cfg(i).elemprop=cfg(i).elem(:,5);
    end
    if(~isfield(cfg(i),'isreoriented') || isempty(cfg(i).isreoriented) || cfg(i).isreoriented==0)
        cfg(i).elem=meshreorient(cfg(i).node,cfg(i).elem(:,1:4));
        cfg(i).isreoriented=1;
    end
    if(~isfield(cfg(i),'facenb') || isempty(cfg(i).facenb))
        cfg(i).facenb=faceneighbors(cfg(i).elem);
    end
    if(~isfield(cfg(i),'evol') || isempty(cfg(i).evol))
        cfg(i).evol=elemvolume(cfg(i).node,cfg(i).elem);
    end
    if(find(cfg(i).evol==0))
        fprintf(1,['degenerated elements are detected: [' sprintf('%d ',find(cfg(i).evol==0)) ']\n']);
        error(['input mesh can not contain degenerated elements, ' ...
            'please double check your input mesh; if you use a ' ...
            'widefield source, please rerun mmcsrcdomain and setting ' ...
            '''Expansion'' option to a larger value (default is 1)']);
    end
    if(~isfield(cfg(i),'srcpos'))
        error('cfg.srcpos field is missing');
    end
    if(~isfield(cfg(i),'srcdir'))
        error('cfg.srcdir field is missing');
    end
    if(~isfield(cfg(i),'e0') || isempty(cfg(i).e0))
        cfg(i).e0=tsearchn(cfg(i).node,cfg(i).elem,cfg(i).srcpos);
    end
    if((isnan(cfg(i).e0) && (isfield(cfg(i),'srctype') ...
           && strcmp(cfg(i).srctype,'pencil')) )|| ischar(cfg(i).e0))
        disp('searching initial element ...');
        face=volface(cfg(i).elem);
        [t,u,v,idx]=raytrace(cfg(i).srcpos,cfg(i).srcdir,cfg(i).node,face);
        if(isempty(idx))
            error('ray does not intersect with the mesh');
        else
            t=t(idx);
            if(cfg(i).e0=='>')
                idx1=find(t>=0);
            elseif(cfg(i).e0=='<')
                idx1=find(t<=0);
            elseif(isnan(cfg(i).e0) || cfg(i).e0=='-')
                idx1=1:length(t);
            else
                error('ray direction specifier is not recognized');
            end
            if(isempty(idx1))
                error('no intersection is found along the ray direction');
            end
            t0=abs(t(idx1));
            [tmin,loc]=min(t0);
            faceidx=idx(idx1(loc));

            % update source position
            cfg(i).srcpos=cfg(i).srcpos+t(idx1(loc))*cfg(i).srcdir;

            % find initial element id
            felem=sort(face(faceidx,:));
            f=cfg(i).elem;
            f=[f(:,[1,2,3]);
               f(:,[2,1,4]);
               f(:,[1,3,4]);
               f(:,[2,4,3])];
            [tf,loc]=ismember(felem,sort(f,2),'rows');
            loc=mod(loc,size(cfg(i).elem,1));
            if(loc==0) loc=size(cfg(i).elem,1); end
            cfg(i).e0=loc;
        end
    end
    if(isnan(cfg(i).e0))  % widefield source
        if(~isfield(cfg(i),'srcparam1') || ~isfield(cfg(i),'srcparam2'))
	        error('for wide-field sources, you must provide srcparam1 and srcparam2');
        end
        if(~isfield(cfg(i),'srctype'))
            cfg(i).srctype='pencil';
        end
        srcdef=struct('srctype',cfg.srctype,'srcpos',cfg.srcpos,'srcdir',cfg.srcdir,...
               'srcparam1',cfg.srcparam1,'srcparam2',cfg.srcparam2);
        sdom=mmcsrcdomain(srcdef,[min(cfg.node);max(cfg.node)]);
        isinside=ismember(round(sdom*1e10)*1e-10,round(cfg(i).node*1e10)*1e-10,'rows');
        if(all(~isinside))
	        if(size(cfg(i).elem,2)==4)
                cfg(i).elem(:,5)=1;
	        end
	        [cfg(i).node,cfg(i).elem] = mmcaddsrc(cfg(i).node,cfg(i).elem,sdom);
	        cfg(i).elemprop=cfg(i).elem(:,5);
            cfg(i).elem=meshreorient(cfg(i).node,cfg(i).elem(:,1:4));
            cfg(i).facenb=faceneighbors(cfg(i).elem);
            cfg(i).evol=elemvolume(cfg(i).node,cfg(i).elem);
            cfg(i).isreoriented=1;
        end
        if(strcmp(cfg(i).srctype,'pencil') || strcmp(cfg(i).srctype,'isotropic'))
            cfg(i).e0=tsearchn(cfg(i).node,cfg(i).elem,cfg(i).srcpos);
            if(isnan(cfg(i).e0))
                cfg(i).e0=-1;
            end
        else
            cfg(i).e0=-1;
        end
    end
    if(~isfield(cfg(i),'elemprop'))
        error('cfg.elemprop field is missing');
    end
    if(~isfield(cfg(i),'nphoton'))
        error('cfg.nphoton field is missing');
    end
    if(~isfield(cfg(i),'prop') || size(cfg(i).prop,1)<max(cfg(i).elemprop)+1 || min(cfg(i).elemprop<=0))
        error('cfg.prop field is missing or insufficient');
    end
end

% must do a fflush, otherwise octave buffers the output until complete
if(exist('OCTAVE_VERSION'))
   fflush(stdout);
end

mmcout=nargout;
if(nargout>=3)
    mmcout=nargout-1;
    varargout{nargout}=cfg;
end

if(nargin<2)
  [varargout{1:mmcout}]=mmc(cfg);
elseif(strcmp(type,'omp'))
  [varargout{1:mmcout}]=mmc(cfg);
elseif(strcmp(type,'sse'))
  [varargout{1:mmcout}]=mmc_sse(cfg);
elseif(strcmp(type,'prep') && nargout==1)
  varargout{1}=cfg;
else
  error('type is not recognized');
end

if(nargout>=4)
  [varargout{3:end}]=deal(varargout{[end 3:end-1]});
end
