inconds;

%Compute closed curve
phi=0:2*pi/(nphi-1):2*pi;
R = R0+epsilon*cos(NFP.*phi);
x = R.*cos(phi);
y = R.*sin(phi);
z = -epsilon.*sin(NFP.*phi);
%Derivatives of closed curve vector
r = [x; y; z];
dr = gradient(r,2*pi/(nphi-1));
sprime = sqrt(sum(dr.^2));
ddr = gradient(dr,2*pi/(nphi-1));
dddr = gradient(ddr,2*pi/(nphi-1));

%Curvature
curv = sqrt(sum(cross(dr,ddr).^2))./sqrt(sum(dr.^2)).^3;
dcurv = gradient(curv,2*pi/(nphi-1));
curv(end-1)=curv(end-2);curv(end)=curv(end-1);curv(1)=curv(end);curv(2)=curv(1);
dcurv(end-2)=dcurv(end-3);dcurv(end-1)=dcurv(end-2);dcurv(end)=dcurv(end-1);dcurv(1)=dcurv(end);dcurv(2)=dcurv(1);dcurv(3)=dcurv(2);
kpok=dcurv./curv;

%Torsion
tors = dot(dr,cross(ddr,dddr))./sum(cross(dr,ddr).^2);
tors(end-2)=tors(end-3);tors(end-1)=tors(end-2);tors(end)=tors(end-1);tors(1)=tors(end);tors(2)=tors(1);tors(3)=tors(2);

%Length of the axis
L = trapz(phi,sprime);

%Number of rotations of the normal vector
tangent = dr./sprime;
normal = gradient(tangent,2*pi/(nphi-1))./sprime./curv;
quadrant = 0; nNormal = 0; diffQuadrant = 0; qnew=0;
for i=1:nphi
    normalx=normal(1,i)*cos(2*pi*i/nphi)+normal(2,i)*sin(2*pi*i/nphi);
    normaly=normal(3,i);
    if norm(normalx) > norm(normaly)
        if normalx>0
            qnew=2;
        else
            qnew=4;
        end
    else
        if normaly > 0
            qnew=1;
        else
            qnew=3;
        end
    end
    if quadrant == 0
        quadrant = qnew;
    else
        diffQuadrant = qnew - quadrant;
    end
    if abs(diffQuadrant) == 3
        diffQuadrant = diffQuadrant/3;
    end
    nNormal = nNormal + diffQuadrant/2;
    quadrant = qnew;
end

%Write curv0 to inconds.m and kpok, tors, sprime, curv
fid = fopen('inconds.m','r');
str = textscan(fid,'%s','Delimiter','\n');
fclose(fid);
str2 = str{1}(1:7);
fid2 = fopen('inconds.m','w');
fprintf(fid2,'%s\n', str2{:});
fprintf(fid2, 'L = %d;\n',L);
fprintf(fid2, 'nNormal = %d;',nNormal);
fclose(fid2);

curvfit=fit(phi',curv','fourier8');
torsfit=fit(phi',tors','fourier8');
sprimefit=fit(phi',sprime','fourier8');

%Initial conditions for QS equations
solinit = bvpinit(phi, @sigmaGuess, iota0);

%Solution of QS equations
options = bvpset('RelTol',10^-3,'AbsTol',10^-5,'NMax',nphi);

sol = bvp4c(@sigmaEq, @sigmaBC, solinit, options, torsfit, curvfit, sprimefit);
sigma = sol.y(1,:);
iota=sol.parameters;

nphiSigma = size(sol.x);
nphiSigma = nphiSigma(2);
options = optimset('Display','off');
mercierParams = zeros(nphi,2);
for i=1:nphi
    isigma = ceil(i*nphiSigma/nphi);
    fun = @(x) mercierFromGB(x,sigma(isigma),curv(i),etab);
    x0 = [0.5,-NFP*i*2*pi/2/nphi];
    mercierParams(i,:) = fsolve(fun,x0,options);
end

mu = mercierParams(:,1);
delta = mercierParams(:,2)+NFP.*phi'/2;

mufit=fit(phi',mu,'fourier8');
deltafit=fit(phi',delta,'fourier8');

muvalues = coeffvalues(mufit);
deltavalues = coeffvalues(deltafit);

%Write mu and delta to SENAC
fid = fopen('surf_input_QS.txt','w');
fprintf(fid2,'NFP = %d\n', NFP);
fprintf(fid2,'RAXIS = %d\n', epsilon);
fprintf(fid, 'ZAXIS = %d\n', epsilon);
fprintf(fid, 'mu = %d', muvalues(1));
for i=1:8
    fprintf(fid, ' %d', muvalues(2*i));
end
fprintf(fid, '\ndelta = %d', 1);
for i=1:8
    fprintf(fid, ' %d', deltavalues(2*i+1));
end
fprintf(fid, '\nB0 = %d', 1);
fclose(fid2);

function F = mercierFromGB(x, sigma, k, etab)
    F(1) = sigma-x(1)*sin(2*x(2))/sqrt(1-x(1)^2);
    F(2) = etab^2/k^2-(1-x(1)*cos(2*x(2)))/sqrt(1-x(1)^2);
end

function yinit = sigmaGuess(s)
    inconds;
    yinit = sin(NFP*s);
end

function dYdt = sigmaEq(s,Y,iota,torsfit,curvfit,sprimefit)
    inconds;
    dYdt = -sprimefit(s)*(2*pi*(1/L)*(iota-nNormal)*(1+Y(1)^2+etab^4/curvfit(s)^4)+2*etab^2*torsfit(s)/curvfit(s)^2);
end

function res = sigmaBC(ya,yb,~,~,~,~)
    inconds;
    res = [ya(1) - yb(1)
           ya(1)-sigma0];
end