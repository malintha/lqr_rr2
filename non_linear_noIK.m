clear;
addpath('./mr/')

% L1, L2: arm lengths
L1 = 0.5;
L2 = 0.5;
theta_min = 0.1;

robot = get2RRobot(L1, L2);

% start and goal positions for the end effector
qinit = [theta_min ; theta_min];

start = [L1*cos(theta_min) + L2*cos(2*theta_min) ...
        L1*sin(theta_min) + L2*sin(2*theta_min)];
target = [-0.5 0.6];

% times for cartesian trajectory generation
dt = 0.1;
Tf = 5;
% calculate the cartesian trajectory
st_tr = trvec2tform([start 0]);
target_tr = trvec2tform([target 0]);
traj = CartesianTrajectory(st_tr, target_tr, Tf, Tf/dt, 5);

% system matrices for LQR
A = eye(2);
B = @(theta1,theta2) [-L1*sin(theta1)-L2*sin(theta1+theta2) -L2*sin(theta1+theta2); ...
                    L1*cos(theta1)+L2*cos(theta1+theta2) L2*cos(theta1+theta2);];
                
% cost matrices
Q = eye(2)*100;
R = [1 0;
    0 1];

% initial conditions for the system
q = qinit;
x0 = [start'; q(1); q(2)];

% matrices for plotting
% using a different plot for saving the animation values because it is slow
% when the time resolution is too high, especially when the results from the
% ODE integration is passed.

xs = [];
es = [];
xs_anim = [];

for i=1:length(traj)
    if i<length(traj)
        [~, x_bar] = TransToRp(traj{i});
    else
        [~, x_bar] = TransToRp(traj{end});
    end
    x_bar = x_bar(1:2);
    
%     linearized system around a fixed point (last known state/initial condition)
    Bt = B(x0(3), x0(4));
    
%     get the LQR gain matrix
    k = lqr(A, Bt, Q, R);
    
% solve the system with kinematics
% use state as [x y theta1 theta2] to progress the system
    tspan = [0 dt];
    [~, xt] = ode45(@(t,xt)non_sys_noIK(xt, x_bar, k), tspan, x0);
    x0 = xt(end,:)';
    
    % plotting data
    es = [es; xt(:,1:2)-x_bar(1:2)'];
    xs = [xs; xt];
    xs_anim = [xs_anim; x0'];
end

% animate the robot
qs = xs_anim(:,3:4);
figure('Renderer', 'painters', 'Position', [1500 100 600 600])
f1 = show(robot,qs(1,:)');
view(2);
ax = gca;
ax.Projection = 'orthographic';
hold on
framesPerSecond = length(qs)/Tf;
r = rateControl(framesPerSecond);
tic
for i = 1:length(qs)
    f1 = show(robot,qs(i,:)','PreservePlot',false);
%     drawnow
    h=findall(f1); %finding all objects in figure
    hlines=h.findobj('Type','Line'); %finding line object 
    %editing line object properties
    for j=1:2
        hlines(j).LineWidth = 3; %chanding line width
        hlines(j).Color=[1 0 0.5];%changing line color
        hlines(j).Marker='o';%changing marker type
        hlines(j).MarkerSize=5; %changing marker size
    end

% %     save to gif
    filename = 'non_linear_noIK.gif';
    frame = getframe(1);
    im = frame2im(frame);
    [imind,cm] = rgb2ind(im,256);
    if i == 1 
      imwrite(imind,cm,filename,'gif', 'Loopcount',inf);
    else
      imwrite(imind,cm,filename,'gif','Writemode','append', 'DelayTime', dt);
    end
    waitfor(r);
end
hold off
toc
reset(r)
% visualize the plots
% fprintf('Total control: %d', norm(us));
ddt = Tf/length(es);
t = (ddt:ddt:length(es)*ddt);
figure
plot(t,es(:,1),'-r',t,es(:,2),'-g','LineWidth',1);
xlabel('Time (s)');
ylabel('Absolute error (m)');

figure
plot(t,xs(:,1),'-r',t,xs(:,2),'-g','LineWidth',1);
legend('X','Y');
xlabel('Time (s)');
ylabel('Displacement(m)');


