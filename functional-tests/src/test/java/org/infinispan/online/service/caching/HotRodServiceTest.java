package org.infinispan.online.service.caching;


import java.io.IOException;
import java.net.MalformedURLException;
import java.net.URL;
import io.fabric8.openshift.client.OpenShiftClient;
import org.arquillian.cube.openshift.impl.requirement.RequiresOpenshift;
import org.arquillian.cube.requirement.ArquillianConditionalRunner;
import org.infinispan.online.service.utils.DeploymentHelper;
import org.infinispan.online.service.utils.OpenShiftClientCreator;
import org.infinispan.online.service.utils.OpenShiftHandle;
import org.infinispan.online.service.utils.ReadinessCheck;
import org.jboss.arquillian.container.test.api.Deployment;
import org.jboss.shrinkwrap.api.Archive;
import org.jboss.shrinkwrap.api.ShrinkWrap;
import org.jboss.shrinkwrap.api.spec.WebArchive;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;

@RunWith(ArquillianConditionalRunner.class)
@RequiresOpenshift
public class HotRodServiceTest {

   OpenShiftClient client = OpenShiftClientCreator.getClient();
   OpenShiftHandle handle = new OpenShiftHandle(client);

   ReadinessCheck readinessCheck = new ReadinessCheck();

   @Deployment
   public static Archive<?> deploymentApp() {
      return ShrinkWrap
         .create(WebArchive.class, "test.war")
         .addAsLibraries(DeploymentHelper.testLibs())
         .addPackage(ReadinessCheck.class.getPackage());
   }

   @Before
   public void before() throws MalformedURLException {
      readinessCheck.waitUntilAllPodsAreReady(client);
   }

   @Test
   public void myTest() throws IOException {
      URL serviceUrl = handle.getServiceWithName("myservice");
      System.out.println("Tested");

      //....do something with serviceUrl
   }
}
